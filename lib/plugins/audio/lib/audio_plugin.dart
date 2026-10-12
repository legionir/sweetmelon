import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef AudioEventEmitter = Future<void> Function(String event, dynamic data);

class AudioPlugin extends Plugin {
  final AudioEventEmitter? eventEmitter;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentRecordingPath;
  StreamSubscription<PlayerState>? _playerSub;
  StreamSubscription<Duration>? _positionSub;

  AudioPlugin({this.eventEmitter});

  @override
  String get name => 'audio';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Audio recorder and player plugin';

  @override
  List<String> get requiredPermissions => ['microphone'];

  @override
  List<String> get supportedMethods => [
        'startRecording',
        'stopRecording',
        'isRecording',
        'play',
        'pause',
        'resume',
        'stop',
        'seek',
        'isPlaying',
        'getDuration',
        'getPosition',
        'setVolume',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    _playerSub = _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;

      if (eventEmitter != null) {
        eventEmitter!('audio.playerState', {
          'state': state.name,
          'isPlaying': _isPlaying,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });

    _positionSub = _player.onPositionChanged.listen((position) {
      if (eventEmitter != null && _isPlaying) {
        eventEmitter!('audio.position', {
          'positionMs': position.inMilliseconds,
          'positionSec': position.inSeconds,
        });
      }
    });
  }

  @override
  Future<void> onDispose() async {
    await _playerSub?.cancel();
    await _positionSub?.cancel();

    if (_isRecording) {
      await _recorder.stop();
    }
    await _recorder.dispose();
    await _player.dispose();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'startRecording':
        return _startRecording(args);
      case 'stopRecording':
        return _stopRecording();
      case 'isRecording':
        return {'recording': _isRecording};
      case 'play':
        return _play(args);
      case 'pause':
        return _pause();
      case 'resume':
        return _resume();
      case 'stop':
        return _stop();
      case 'seek':
        return _seek(args);
      case 'isPlaying':
        return {'playing': _isPlaying};
      case 'getDuration':
        return _getDuration();
      case 'getPosition':
        return _getPosition();
      case 'setVolume':
        return _setVolume(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'recording': _isRecording,
          'playing': _isPlaying,
          'currentRecordingPath': _currentRecordingPath,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _startRecording(
      Map<String, dynamic> args) async {
    if (_isRecording) {
      return {'started': false, 'reason': 'already_recording'};
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      return {'started': false, 'reason': 'permission_denied'};
    }

    final fileName = args['fileName'] as String? ??
        'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final dir = await getApplicationDocumentsDirectory();
    final recordDir = Directory(p.join(dir.path, 'recordings'));
    await recordDir.create(recursive: true);

    final filePath = p.join(recordDir.path, fileName);
    _currentRecordingPath = filePath;

    final encoder = _parseEncoder(args['encoder'] as String? ?? 'aacLc');
    final bitRate = (args['bitRate'] as num?)?.toInt() ?? 128000;
    final sampleRate = (args['sampleRate'] as num?)?.toInt() ?? 44100;

    await _recorder.start(
      RecordConfig(
        encoder: encoder,
        bitRate: bitRate,
        sampleRate: sampleRate,
      ),
      path: filePath,
    );

    _isRecording = true;

    BridgeLogger.info('Audio', 'Recording started: $filePath');

    return {
      'started': true,
      'path': filePath,
      'fileName': fileName,
    };
  }

  Future<Map<String, dynamic>> _stopRecording() async {
    if (!_isRecording) {
      return {'stopped': false, 'reason': 'not_recording'};
    }

    final path = await _recorder.stop();
    _isRecording = false;

    BridgeLogger.info('Audio', 'Recording stopped: $path');

    if (path != null) {
      final file = File(path);
      final stat = await file.stat();

      return {
        'stopped': true,
        'path': path,
        'fileName': p.basename(path),
        'size': stat.size,
      };
    }

    return {
      'stopped': true,
      'path': _currentRecordingPath,
    };
  }

  Future<Map<String, dynamic>> _play(Map<String, dynamic> args) async {
    final source = args['path'] as String? ?? args['url'] as String?;

    if (source == null || source.isEmpty) {
      return {'playing': false, 'reason': 'no_source'};
    }

    final volume = (args['volume'] as num?)?.toDouble() ?? 1.0;

    await _player.setVolume(volume);

    if (source.startsWith('http://') || source.startsWith('https://')) {
      await _player.play(UrlSource(source));
    } else {
      await _player.play(DeviceFileSource(source));
    }

    _isPlaying = true;

    return {
      'playing': true,
      'source': source,
    };
  }

  Future<Map<String, dynamic>> _pause() async {
    await _player.pause();
    _isPlaying = false;
    return {'paused': true};
  }

  Future<Map<String, dynamic>> _resume() async {
    await _player.resume();
    _isPlaying = true;
    return {'resumed': true};
  }

  Future<Map<String, dynamic>> _stop() async {
    await _player.stop();
    _isPlaying = false;
    return {'stopped': true};
  }

  Future<Map<String, dynamic>> _seek(Map<String, dynamic> args) async {
    final positionMs = (args['positionMs'] as num).toInt();
    await _player.seek(Duration(milliseconds: positionMs));
    return {'seeked': true, 'positionMs': positionMs};
  }

  Future<Map<String, dynamic>> _getDuration() async {
    final duration = await _player.getDuration();
    return {
      'durationMs': duration?.inMilliseconds ?? 0,
      'durationSec': duration?.inSeconds ?? 0,
    };
  }

  Future<Map<String, dynamic>> _getPosition() async {
    final position = await _player.getCurrentPosition();
    return {
      'positionMs': position?.inMilliseconds ?? 0,
      'positionSec': position?.inSeconds ?? 0,
    };
  }

  Future<Map<String, dynamic>> _setVolume(Map<String, dynamic> args) async {
    final volume = (args['volume'] as num).toDouble().clamp(0.0, 1.0);
    await _player.setVolume(volume);
    return {'volume': volume};
  }

  AudioEncoder _parseEncoder(String encoder) {
    switch (encoder) {
      case 'aacLc':
        return AudioEncoder.aacLc;
      case 'aacEld':
        return AudioEncoder.aacEld;
      case 'aacHe':
        return AudioEncoder.aacHe;
      case 'opus':
        return AudioEncoder.opus;
      case 'wav':
        return AudioEncoder.wav;
      case 'flac':
        return AudioEncoder.flac;
      default:
        return AudioEncoder.aacLc;
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'play':
        final path = args['path'] ?? args['url'];
        if (path is! String || path.isEmpty) {
          return ValidationResult.invalid('path or url is required');
        }
        return ValidationResult.valid();

      case 'seek':
        final pos = args['positionMs'];
        if (pos is! num) {
          return ValidationResult.invalid(
              'positionMs is required and must be a number');
        }
        return ValidationResult.valid();

      case 'setVolume':
        final vol = args['volume'];
        if (vol is! num) {
          return ValidationResult.invalid(
              'volume is required and must be a number (0.0 - 1.0)');
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
