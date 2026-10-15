import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Runs sherpa-onnx in its own isolate.
///
/// Recognising a few seconds of speech or synthesising a sentence takes
/// seconds on a phone. On the main isolate that would stall every other call
/// of the bridge, so the models live here and the plugin talks to them with
/// messages. Each isolate has its own native bindings, which the worker
/// initialises itself.
class SpeechWorker {
  SpeechWorker._(this._isolate, this._send, this._receive);

  final Isolate _isolate;
  final SendPort _send;
  final ReceivePort _receive;
  final Map<int, Completer<dynamic>> _pending = {};
  int _nextId = 0;

  static Future<SpeechWorker> spawn() async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(_entry, ready.sendPort);
    final send = await ready.first as SendPort;
    ready.close();

    final receive = ReceivePort();
    final worker = SpeechWorker._(isolate, send, receive);
    receive.listen(worker._onMessage);
    send.send(receive.sendPort);
    return worker;
  }

  void _onMessage(dynamic message) {
    final list = message as List;
    final completer = _pending.remove(list[0] as int);
    if (completer == null) return;
    if (list[1] == true) {
      completer.complete(list[2]);
    } else {
      completer.completeError(StateError(list[2] as String));
    }
  }

  /// Sends a command and waits for its answer.
  Future<dynamic> request(String op, Map<String, dynamic> data) {
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _send.send([id, op, data]);
    return completer.future;
  }

  void dispose() {
    for (final completer in _pending.values) {
      completer.completeError(StateError('Worker stopped'));
    }
    _pending.clear();
    _receive.close();
    _isolate.kill(priority: Isolate.immediate);
  }

  // ───────────────────────── isolate side ─────────────────────────

  static void _entry(SendPort ready) {
    final commands = ReceivePort();
    ready.send(commands.sendPort);

    SendPort? reply;
    final state = _WorkerState();
    commands.listen((message) {
      if (message is SendPort) {
        reply = message;
        return;
      }
      final list = message as List;
      final id = list[0] as int;
      try {
        final result = state.handle(
            list[1] as String, (list[2] as Map).cast<String, dynamic>());
        reply?.send([id, true, result]);
      } catch (e) {
        reply?.send([id, false, e.toString()]);
      }
    });
  }
}

class _WorkerState {
  bool _initialised = false;
  sherpa.OfflineRecognizer? _recognizer;
  sherpa.OfflineTts? _tts;
  String _asrType = '';

  void _init() {
    if (_initialised) return;
    sherpa.initBindings();
    _initialised = true;
  }

  dynamic handle(String op, Map<String, dynamic> data) {
    _init();
    switch (op) {
      case 'loadAsr':
        return _loadAsr(data);
      case 'freeAsr':
        _recognizer?.free();
        _recognizer = null;
        return null;
      case 'transcribe':
        return _transcribe(data);
      case 'transcribeFile':
        final wave = sherpa.readWave(data['path'] as String);
        if (wave.sampleRate == 0) throw StateError('Cannot read the WAV file');
        return _recognise(wave.samples, wave.sampleRate);
      case 'loadTts':
        return _loadTts(data);
      case 'freeTts':
        _tts?.free();
        _tts = null;
        return null;
      case 'synth':
        return _synth(data);
      default:
        throw StateError('Unknown command $op');
    }
  }

  // ── recognition ──

  dynamic _loadAsr(Map<String, dynamic> d) {
    _recognizer?.free();
    _recognizer = null;

    final type = d['type'] as String;
    final threads = d['threads'] as int? ?? 2;
    final model = sherpa.OfflineModelConfig(
      whisper: type == 'whisper'
          ? sherpa.OfflineWhisperModelConfig(
              encoder: d['encoder'] as String,
              decoder: d['decoder'] as String,
              language: d['language'] as String? ?? '',
              task: d['task'] as String? ?? 'transcribe',
              tailPaddings: d['tailPaddings'] as int? ?? -1,
            )
          : const sherpa.OfflineWhisperModelConfig(),
      transducer: type == 'transducer'
          ? sherpa.OfflineTransducerModelConfig(
              encoder: d['encoder'] as String,
              decoder: d['decoder'] as String,
              joiner: d['joiner'] as String,
            )
          : const sherpa.OfflineTransducerModelConfig(),
      senseVoice: type == 'sense_voice'
          ? sherpa.OfflineSenseVoiceModelConfig(
              model: d['model'] as String,
              language: d['language'] as String? ?? '',
              useInverseTextNormalization: d['useItn'] as bool? ?? true,
            )
          : const sherpa.OfflineSenseVoiceModelConfig(),
      paraformer: type == 'paraformer'
          ? sherpa.OfflineParaformerModelConfig(model: d['model'] as String)
          : const sherpa.OfflineParaformerModelConfig(),
      tokens: d['tokens'] as String,
      numThreads: threads,
      debug: false,
      provider: 'cpu',
    );

    _recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: model,
        decodingMethod: d['decodingMethod'] as String? ?? 'greedy_search',
      ),
    );
    _asrType = type;
    return {'type': type};
  }

  dynamic _transcribe(Map<String, dynamic> d) {
    final samples =
        (d['samples'] as TransferableTypedData).materialize().asFloat32List();
    return _recognise(samples, d['sampleRate'] as int);
  }

  /// Whisper reads at most 30 s at a time, so longer speech is cut into
  /// windows of 28 s and the texts are joined.
  dynamic _recognise(Float32List samples, int sampleRate) {
    final recognizer = _recognizer;
    if (recognizer == null) throw StateError('No recognition model loaded');

    if (samples.isEmpty)
      return {'text': '', 'audioSeconds': 0.0, 'decodeMs': 0};

    final window = _asrType == 'whisper' ? sampleRate * 28 : samples.length;
    final texts = <String>[];
    final started = DateTime.now();
    for (var start = 0; start < samples.length; start += window) {
      final end =
          start + window < samples.length ? start + window : samples.length;
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
          samples: Float32List.sublistView(samples, start, end),
          sampleRate: sampleRate,
        );
        recognizer.decode(stream);
        final text = recognizer.getResult(stream).text.trim();
        if (text.isNotEmpty) texts.add(text);
      } finally {
        stream.free();
      }
    }
    return {
      'text': texts.join(' '),
      'audioSeconds': samples.length / sampleRate,
      'decodeMs': DateTime.now().difference(started).inMilliseconds,
    };
  }

  // ── synthesis ──

  dynamic _loadTts(Map<String, dynamic> d) {
    _tts?.free();
    _tts = null;

    final type = d['type'] as String;
    final threads = d['threads'] as int? ?? 2;
    final model = sherpa.OfflineTtsModelConfig(
      vits: type == 'vits'
          ? sherpa.OfflineTtsVitsModelConfig(
              model: d['model'] as String,
              lexicon: d['lexicon'] as String? ?? '',
              tokens: d['tokens'] as String,
              dataDir: d['dataDir'] as String? ?? '',
              noiseScale: (d['noiseScale'] as num?)?.toDouble() ?? 0.667,
              noiseScaleW: (d['noiseScaleW'] as num?)?.toDouble() ?? 0.8,
              lengthScale: (d['lengthScale'] as num?)?.toDouble() ?? 1.0,
            )
          : const sherpa.OfflineTtsVitsModelConfig(),
      kokoro: type == 'kokoro'
          ? sherpa.OfflineTtsKokoroModelConfig(
              model: d['model'] as String,
              voices: d['voices'] as String,
              tokens: d['tokens'] as String,
              dataDir: d['dataDir'] as String? ?? '',
              lexicon: d['lexicon'] as String? ?? '',
              lengthScale: (d['lengthScale'] as num?)?.toDouble() ?? 1.0,
              lang: d['lang'] as String? ?? '',
            )
          : const sherpa.OfflineTtsKokoroModelConfig(),
      numThreads: threads,
      debug: false,
      provider: 'cpu',
    );

    final tts = sherpa.OfflineTts(
      sherpa.OfflineTtsConfig(
        model: model,
        maxNumSenetences: d['maxNumSentences'] as int? ?? 1,
        silenceScale: (d['silenceScale'] as num?)?.toDouble() ?? 0.2,
      ),
    );
    _tts = tts;
    return {
      'type': type,
      'sampleRate': tts.sampleRate,
      'speakers': tts.numSpeakers,
    };
  }

  dynamic _synth(Map<String, dynamic> d) {
    final tts = _tts;
    if (tts == null) throw StateError('No synthesis model loaded');

    final started = DateTime.now();
    final audio = tts.generateWithConfig(
      text: d['text'] as String,
      config: sherpa.OfflineTtsGenerationConfig(
        sid: d['sid'] as int? ?? 0,
        speed: (d['speed'] as num?)?.toDouble() ?? 1.0,
        silenceScale: (d['silenceScale'] as num?)?.toDouble() ?? 0.2,
      ),
    );
    if (audio.samples.isEmpty) throw StateError('The model produced no audio');

    final ok = sherpa.writeWave(
      filename: d['output'] as String,
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );
    if (!ok) throw StateError('Could not write the audio file');
    return {
      'path': d['output'],
      'sampleRate': audio.sampleRate,
      'durationMs': (audio.samples.length * 1000 / audio.sampleRate).round(),
      'synthMs': DateTime.now().difference(started).inMilliseconds,
    };
  }
}
