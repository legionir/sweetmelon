import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

import 'speech_worker.dart';

typedef SpeechEventEmitter = Future<void> Function(String event, dynamic data);

/// Speech to text and text to speech, both offline (sherpa-onnx).
///
/// Models come from the `modelManager` plugin (kinds `stt` and `tts`): the user
/// imports a Whisper (or SenseVoice, Paraformer, transducer) model and a Piper
/// or Kokoro voice from their own files. Recognition and synthesis run in a
/// worker isolate, so they never block other calls.
///
/// Hold-to-talk: `startListening` records the microphone, `stopListening`
/// ends the recording and returns the recognised text. `speak` queues text,
/// synthesises it ahead of playback and plays it.
class SpeechOfflinePlugin extends Plugin {
  SpeechOfflinePlugin({this.eventEmitter, ModelStore? store}) : _store = store;

  final SpeechEventEmitter? eventEmitter;
  ModelStore? _store;

  SpeechWorker? _worker;
  Future<SpeechWorker>? _spawning;

  // Recognition
  String? _asrModelId;
  String? _asrType;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  List<Float32List> _chunks = [];
  int _sampleCount = 0;
  int _recordRate = 16000;
  int _maxSamples = 0;
  bool _recording = false;
  DateTime _lastLevel = DateTime.fromMillisecondsSinceEpoch(0);

  // Synthesis
  String? _ttsModelId;
  int _ttsRate = 0;
  int _ttsSpeakers = 0;
  double _ttsSilenceScale = 0.2;
  AudioPlayer? _player;
  final List<_SpeakItem> _queue = [];
  bool _pumping = false;
  int _speakEpoch = 0;
  int _sequence = 0;
  double _volume = 1.0;

  @override
  String get name => 'speechOffline';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Offline speech recognition and synthesis';

  // The microphone is requested by `startListening` only. Synthesis, loading
  // models and reading the status need no permission.
  @override
  List<String> get requiredPermissions => const [];

  @override
  List<String> get supportedMethods => [
        'loadRecognizer',
        'unloadRecognizer',
        'startListening',
        'stopListening',
        'cancelListening',
        'transcribeFile',
        'loadSynthesizer',
        'unloadSynthesizer',
        'speak',
        'synthesize',
        'stopSpeaking',
        'setVolume',
        'status',
        'getInfo',
      ];

  Future<ModelStore> _getStore() async => _store ??= await ModelStore.forApp();

  Future<SpeechWorker> _getWorker() =>
      _spawning ??= SpeechWorker.spawn().then((w) => _worker = w);

  @override
  Future<void> onDispose() async {
    await _cancelRecording();
    await _stopSpeaking();
    _worker?.dispose();
    _worker = null;
    _spawning = null;
    await _player?.dispose();
    await _recorder.dispose();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'loadRecognizer':
        return _loadRecognizer(args);
      case 'unloadRecognizer':
        return _unloadRecognizer();
      case 'startListening':
        return _startListening(args);
      case 'stopListening':
        return _stopListening(args);
      case 'cancelListening':
        await _cancelRecording();
        return {'cancelled': true};
      case 'transcribeFile':
        return _transcribeFile(args);
      case 'loadSynthesizer':
        return _loadSynthesizer(args);
      case 'unloadSynthesizer':
        return _unloadSynthesizer();
      case 'speak':
        return _speak(args);
      case 'synthesize':
        return _synthesize(args);
      case 'stopSpeaking':
        await _stopSpeaking();
        return {'stopped': true};
      case 'setVolume':
        _volume = ((args['volume'] as num).toDouble()).clamp(0.0, 1.0);
        await _player?.setVolume(_volume);
        return {'volume': _volume};
      case 'status':
      case 'getInfo':
        return _status();
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<void> _emit(String event, Map<String, dynamic> data) async {
    await eventEmitter?.call(event, data);
  }

  Map<String, dynamic> _status() => {
        'name': name,
        'version': version,
        'recognizer': {
          'loaded': _asrModelId != null,
          'modelId': _asrModelId,
          'type': _asrType,
          'recording': _recording,
        },
        'synthesizer': {
          'loaded': _ttsModelId != null,
          'modelId': _ttsModelId,
          'sampleRate': _ttsRate,
          'speakers': _ttsSpeakers,
          'speaking': _pumping || _queue.isNotEmpty,
          'queued': _queue.length,
        },
      };

  // ───────────────────────── recognition ─────────────────────────

  /// Loads a speech recognition model: `modelId` of a `modelManager` model
  /// (kind `stt`). `type` is `auto` (default), `whisper`, `transducer`,
  /// `sense_voice` or `paraformer`.
  Future<Map<String, dynamic>> _loadRecognizer(
      Map<String, dynamic> args) async {
    final store = await _getStore();
    final id = args['modelId'] as String;
    final entry = await store.get(id);
    if (entry == null) throw ArgumentError('Model "$id" not found');

    final requested = args['type'] == null || args['type'] == 'auto'
        ? null
        : asrTypeFromName(args['type'] as String);
    if (args['type'] != null && args['type'] != 'auto' && requested == null) {
      throw ArgumentError('Unknown type "${args['type']}"');
    }
    final files = detectAsrFiles(entry.files, requested: requested);
    if (files == null) {
      throw ArgumentError(
          'Model "${entry.name}" is missing files. Whisper needs an encoder, a '
          'decoder and tokens; SenseVoice and Paraformer a model and tokens.');
    }

    await _emit(
        'speechOffline.state', {'part': 'recognizer', 'state': 'loading'});
    try {
      final worker = await _getWorker();
      await worker.request('loadAsr', {
        'type': asrTypeName(files.type),
        'tokens': files.tokens.path,
        'encoder': files.encoder?.path,
        'decoder': files.decoder?.path,
        'joiner': files.joiner?.path,
        'model': files.model?.path,
        'language': args['language'] ?? '',
        'task': args['task'] ?? 'transcribe',
        'threads': args['threads'] ?? 2,
        'tailPaddings': args['tailPaddings'] ?? -1,
        'decodingMethod': args['decodingMethod'] ?? 'greedy_search',
        'useItn': args['useItn'] ?? true,
      });
    } catch (e) {
      await _emit('speechOffline.state',
          {'part': 'recognizer', 'state': 'error', 'message': e.toString()});
      rethrow;
    }

    _asrModelId = id;
    _asrType = asrTypeName(files.type);
    await _emit('speechOffline.state', {
      'part': 'recognizer',
      'state': 'ready',
      'modelId': id,
      'type': _asrType
    });
    return {'loaded': true, 'modelId': id, 'type': _asrType};
  }

  Future<Map<String, dynamic>> _unloadRecognizer() async {
    await _cancelRecording();
    await _worker?.request('freeAsr', {});
    _asrModelId = null;
    _asrType = null;
    await _emit(
        'speechOffline.state', {'part': 'recognizer', 'state': 'unloaded'});
    return {'unloaded': true};
  }

  /// Starts recording the microphone (16 kHz mono). The permission is asked
  /// here, the first time.
  Future<Map<String, dynamic>> _startListening(
      Map<String, dynamic> args) async {
    if (_asrModelId == null) return {'started': false, 'reason': 'not_loaded'};
    if (_recording) return {'started': false, 'reason': 'already_recording'};
    if (!await _recorder.hasPermission()) {
      return {'started': false, 'reason': 'permission_denied'};
    }

    _recordRate = (args['sampleRate'] as num?)?.toInt() ?? 16000;
    final maxSeconds = (args['maxSeconds'] as num?)?.toInt() ?? 60;
    _maxSamples = _recordRate * maxSeconds;
    _chunks = [];
    _sampleCount = 0;

    final stream = await _recorder.startStream(RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _recordRate,
      numChannels: 1,
    ));
    _recording = true;
    _micSub = stream.listen(_onMicData, onError: (Object e) {
      BridgeLogger.error('SpeechOffline', 'Microphone error: $e');
      _emit('speechOffline.error', {'message': e.toString()});
    });
    await _emit('speechOffline.listening', {'listening': true});
    return {'started': true, 'sampleRate': _recordRate};
  }

  void _onMicData(Uint8List bytes) {
    if (!_recording || _sampleCount >= _maxSamples) return;
    final count = bytes.length ~/ 2;
    final view = ByteData.sublistView(bytes);
    final samples = Float32List(count);
    var energy = 0.0;
    for (var i = 0; i < count; i++) {
      final value = view.getInt16(i * 2, Endian.little) / 32768.0;
      samples[i] = value;
      energy += value * value;
    }
    _chunks.add(samples);
    _sampleCount += count;

    final now = DateTime.now();
    if (count > 0 &&
        now.difference(_lastLevel) > const Duration(milliseconds: 80)) {
      _lastLevel = now;
      // Speech is mostly quiet in RMS terms: stretch it so the meter moves.
      final rms = (energy / count);
      final level = (rms * 40).clamp(0.0, 1.0).toDouble();
      _emit('speechOffline.level', {'level': level});
    }

    if (_sampleCount >= _maxSamples) {
      _emit('speechOffline.limit', {'maxSamples': _maxSamples});
    }
  }

  /// Ends the recording and recognises it. Returns `{text, audioSeconds,
  /// decodeMs}`. With `recognize: false` the recording is dropped.
  Future<Map<String, dynamic>> _stopListening(Map<String, dynamic> args) async {
    if (!_recording) return {'text': '', 'reason': 'not_recording'};
    await _endRecording();
    final recognize = args['recognize'] as bool? ?? true;

    final samples = _joinChunks();
    _chunks = [];
    await _emit('speechOffline.listening', {'listening': false});
    if (!recognize || samples.isEmpty) {
      return {'text': '', 'audioSeconds': samples.length / _recordRate};
    }

    await _emit('speechOffline.transcribing',
        {'audioSeconds': samples.length / _recordRate});
    final worker = await _getWorker();
    final result = await worker.request('transcribe', {
      'samples': TransferableTypedData.fromList([samples]),
      'sampleRate': _recordRate,
    }) as Map;
    final out = result.cast<String, dynamic>();
    await _emit('speechOffline.result', out);
    return out;
  }

  Future<void> _cancelRecording() async {
    if (!_recording) return;
    await _endRecording();
    _chunks = [];
    await _emit('speechOffline.listening', {'listening': false});
  }

  Future<void> _endRecording() async {
    _recording = false;
    await _micSub?.cancel();
    _micSub = null;
    await _recorder.stop();
  }

  Float32List _joinChunks() {
    final total = _sampleCount > _maxSamples ? _maxSamples : _sampleCount;
    final joined = Float32List(total);
    var offset = 0;
    for (final chunk in _chunks) {
      if (offset >= total) break;
      final take =
          offset + chunk.length > total ? total - offset : chunk.length;
      joined.setRange(offset, offset + take, chunk);
      offset += take;
    }
    return joined;
  }

  /// Recognises a WAV file inside the app's own folders.
  Future<Map<String, dynamic>> _transcribeFile(
      Map<String, dynamic> args) async {
    if (_asrModelId == null) return {'text': '', 'reason': 'not_loaded'};
    final path = args['path'] as String;
    await _requireAppPath(path);
    final worker = await _getWorker();
    final result =
        await worker.request('transcribeFile', {'path': path}) as Map;
    return result.cast<String, dynamic>();
  }

  // ───────────────────────── synthesis ─────────────────────────

  /// Loads a voice: `modelId` of a `modelManager` model (kind `tts`). `type`
  /// is `auto` (default), `vits` (Piper) or `kokoro`.
  Future<Map<String, dynamic>> _loadSynthesizer(
      Map<String, dynamic> args) async {
    final store = await _getStore();
    final id = args['modelId'] as String;
    final entry = await store.get(id);
    if (entry == null) throw ArgumentError('Model "$id" not found');

    final requested = args['type'] == null || args['type'] == 'auto'
        ? null
        : ttsTypeFromName(args['type'] as String);
    if (args['type'] != null && args['type'] != 'auto' && requested == null) {
      throw ArgumentError('Unknown type "${args['type']}"');
    }
    final files = detectTtsFiles(
      entry.files,
      entry.directories,
      entry.dir,
      requested: requested,
    );
    if (files == null) {
      throw ArgumentError(
          'Voice "${entry.name}" is missing files. A Piper voice needs the '
          '.onnx model and tokens.txt (and the espeak-ng-data folder).');
    }

    await _stopSpeaking();
    await _emit(
        'speechOffline.state', {'part': 'synthesizer', 'state': 'loading'});
    try {
      final worker = await _getWorker();
      final info = await worker.request('loadTts', {
        'type': ttsTypeName(files.type),
        'model': files.model.path,
        'tokens': files.tokens.path,
        'lexicon': files.lexicon?.path ?? '',
        'voices': files.voices?.path ?? '',
        'dataDir': files.dataDir ?? '',
        'threads': args['threads'] ?? 2,
        'noiseScale': args['noiseScale'] ?? 0.667,
        'noiseScaleW': args['noiseScaleW'] ?? 0.8,
        'lengthScale': args['lengthScale'] ?? 1.0,
        'maxNumSentences': args['maxNumSentences'] ?? 1,
        'silenceScale': args['silenceScale'] ?? 0.2,
        'lang': args['lang'] ?? '',
      }) as Map;
      _ttsRate = info['sampleRate'] as int;
      _ttsSpeakers = info['speakers'] as int;
    } catch (e) {
      await _emit('speechOffline.state',
          {'part': 'synthesizer', 'state': 'error', 'message': e.toString()});
      rethrow;
    }

    _ttsModelId = id;
    _ttsSilenceScale = (args['silenceScale'] as num?)?.toDouble() ?? 0.2;
    await _emit('speechOffline.state', {
      'part': 'synthesizer',
      'state': 'ready',
      'modelId': id,
      'sampleRate': _ttsRate,
      'speakers': _ttsSpeakers,
    });
    return {
      'loaded': true,
      'modelId': id,
      'type': ttsTypeName(files.type),
      'sampleRate': _ttsRate,
      'speakers': _ttsSpeakers,
    };
  }

  Future<Map<String, dynamic>> _unloadSynthesizer() async {
    await _stopSpeaking();
    await _worker?.request('freeTts', {});
    _ttsModelId = null;
    _ttsRate = 0;
    _ttsSpeakers = 0;
    await _emit(
        'speechOffline.state', {'part': 'synthesizer', 'state': 'unloaded'});
    return {'unloaded': true};
  }

  /// Queues [text] to be spoken. It is synthesised straight away (while the
  /// previous text plays) and played in order. Events `speechOffline.speak`:
  /// `{id, state: started|finished|error|idle}`.
  Future<Map<String, dynamic>> _speak(Map<String, dynamic> args) async {
    if (_ttsModelId == null) return {'queued': false, 'reason': 'not_loaded'};

    final id = (args['id'] as String?) ?? 's${++_sequence}';
    final text = args['text'] as String;
    final speed = (args['speed'] as num?)?.toDouble() ?? 1.0;
    final sid = (args['speakerId'] as num?)?.toInt() ?? 0;
    final silence =
        (args['silenceScale'] as num?)?.toDouble() ?? _ttsSilenceScale;
    final volume = (args['volume'] as num?)?.toDouble();
    if (volume != null) {
      _volume = volume.clamp(0.0, 1.0);
      await _player?.setVolume(_volume);
    }

    final output = await _newWavPath();
    final worker = await _getWorker();
    final item = _SpeakItem(
      id: id,
      text: text,
      epoch: _speakEpoch,
      path: output,
      synthesis: worker.request('synth', {
        'text': text,
        'sid': sid,
        'speed': speed,
        'silenceScale': silence,
        'output': output,
      }),
    );
    // A failure is reported when the item comes up, not here.
    item.synthesis.ignore();

    _queue.add(item);
    if (!_pumping) unawaited(_pump());
    return {'queued': true, 'id': id};
  }

  Future<void> _pump() async {
    _pumping = true;
    try {
      while (_queue.isNotEmpty) {
        final item = _queue.removeAt(0);
        if (item.epoch != _speakEpoch) {
          await _deleteQuietly(item.path);
          continue;
        }
        try {
          await item.synthesis;
          if (item.epoch != _speakEpoch) {
            await _deleteQuietly(item.path);
            continue;
          }
          await _emit('speechOffline.speak',
              {'id': item.id, 'state': 'started', 'text': item.text});
          await _play(item.path);
          await _emit(
              'speechOffline.speak', {'id': item.id, 'state': 'finished'});
        } catch (e) {
          BridgeLogger.error('SpeechOffline', 'Speak failed: $e');
          await _emit('speechOffline.speak',
              {'id': item.id, 'state': 'error', 'message': e.toString()});
        } finally {
          await _deleteQuietly(item.path);
        }
      }
    } finally {
      _pumping = false;
    }
    await _emit('speechOffline.speak', {'state': 'idle'});
  }

  Future<void> _play(String path) async {
    final player = _player ??= AudioPlayer();
    await player.setVolume(_volume);
    final done = Completer<void>();
    final sub = player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    final stopSub = player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped && !done.isCompleted) done.complete();
    });
    try {
      await player.play(DeviceFileSource(path));
      await done.future;
    } finally {
      await sub.cancel();
      await stopSub.cancel();
    }
  }

  Future<void> _stopSpeaking() async {
    _speakEpoch++;
    for (final item in _queue) {
      await _deleteQuietly(item.path);
    }
    _queue.clear();
    await _player?.stop();
  }

  /// Synthesises [text] into a WAV file and returns its path (no playback).
  Future<Map<String, dynamic>> _synthesize(Map<String, dynamic> args) async {
    if (_ttsModelId == null) return {'path': null, 'reason': 'not_loaded'};
    final worker = await _getWorker();
    final output = await _newWavPath(keep: true);
    final result = await worker.request('synth', {
      'text': args['text'],
      'sid': (args['speakerId'] as num?)?.toInt() ?? 0,
      'speed': (args['speed'] as num?)?.toDouble() ?? 1.0,
      'silenceScale':
          (args['silenceScale'] as num?)?.toDouble() ?? _ttsSilenceScale,
      'output': output,
    }) as Map;
    return result.cast<String, dynamic>();
  }

  Future<String> _newWavPath({bool keep = false}) async {
    final dir = Directory(
        p.join((await getTemporaryDirectory()).path, 'speech_offline'));
    await dir.create(recursive: true);
    return p.join(dir.path,
        '${DateTime.now().microsecondsSinceEpoch}${keep ? '' : '-tmp'}.wav');
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      /* already gone */
    }
  }

  Future<void> _requireAppPath(String path) async {
    final roots = <String>[
      (await getTemporaryDirectory()).path,
      (await getApplicationCacheDirectory()).path,
      (await getApplicationDocumentsDirectory()).path,
      (await getApplicationSupportDirectory()).path,
    ];
    final normalized = p.normalize(path);
    final inside = p.isAbsolute(normalized) &&
        roots.any((root) => p.isWithin(root, normalized));
    if (!inside) {
      throw ArgumentError('File is not inside the app folders: $path');
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'loadRecognizer':
      case 'loadSynthesizer':
        final id = args['modelId'];
        if (id is! String || !modelIdPattern.hasMatch(id)) {
          return ValidationResult.invalid('modelId is required');
        }
        return ValidationResult.valid();
      case 'speak':
      case 'synthesize':
        if (args['text'] is! String ||
            (args['text'] as String).trim().isEmpty) {
          return ValidationResult.invalid('text is required');
        }
        return ValidationResult.valid();
      case 'transcribeFile':
        if (args['path'] is! String) {
          return ValidationResult.invalid('path is required');
        }
        return ValidationResult.valid();
      case 'setVolume':
        if (args['volume'] is! num) {
          return ValidationResult.invalid('volume must be a number (0-1)');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}

class _SpeakItem {
  _SpeakItem({
    required this.id,
    required this.text,
    required this.epoch,
    required this.path,
    required this.synthesis,
  });

  final String id;
  final String text;
  final int epoch;
  final String path;
  final Future<dynamic> synthesis;
}
