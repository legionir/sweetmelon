import 'dart:async';
import 'dart:io';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:video_player/video_player.dart' as vp;

typedef VideoEventEmitter = Future<void> Function(String event, dynamic data);

class VideoPlayerPlugin extends Plugin {
  final VideoEventEmitter? eventEmitter;
  final Map<String, _ManagedPlayer> _players = {};

  VideoPlayerPlugin({this.eventEmitter});

  @override
  String get name => 'videoPlayer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Video player plugin';

  @override
  List<String> get supportedMethods => [
        'create',
        'play',
        'pause',
        'seekTo',
        'setVolume',
        'setPlaybackSpeed',
        'setLooping',
        'getPosition',
        'getDuration',
        'getState',
        'dispose',
        'disposeAll',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    for (final p in _players.values) {
      await p.controller.dispose();
      p.listener?.cancel();
    }
    _players.clear();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'create':
        return _create(args);
      case 'play':
        return _play(args);
      case 'pause':
        return _pause(args);
      case 'seekTo':
        return _seekTo(args);
      case 'setVolume':
        return _setVolume(args);
      case 'setPlaybackSpeed':
        return _setPlaybackSpeed(args);
      case 'setLooping':
        return _setLooping(args);
      case 'getPosition':
        return _getPosition(args);
      case 'getDuration':
        return _getDuration(args);
      case 'getState':
        return _getState(args);
      case 'dispose':
        return _disposePlayer(args);
      case 'disposeAll':
        return _disposeAll();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'activePlayers': _players.keys.toList(),
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _create(Map<String, dynamic> args) async {
    final playerId = args['playerId'] as String? ??
        'vp_${DateTime.now().millisecondsSinceEpoch}';
    final url = args['url'] as String?;
    final filePath = args['path'] as String?;
    final autoPlay = args['autoPlay'] as bool? ?? false;
    final looping = args['looping'] as bool? ?? false;
    final volume = (args['volume'] as num?)?.toDouble() ?? 1.0;

    vp.VideoPlayerController controller;

    if (url != null && url.isNotEmpty) {
      controller = vp.VideoPlayerController.networkUrl(Uri.parse(url));
    } else if (filePath != null && filePath.isNotEmpty) {
      controller = vp.VideoPlayerController.file(File(filePath));
    } else {
      throw ArgumentError('Either url or path is required');
    }

    await controller.initialize();
    await controller.setLooping(looping);
    await controller.setVolume(volume);

    StreamSubscription<void>? listener;
    listener = controller.addListener(() {
      if (eventEmitter != null) {
        eventEmitter!('videoPlayer.state', {
          'playerId': playerId,
          'isPlaying': controller.value.isPlaying,
          'isBuffering': controller.value.isBuffering,
          'isCompleted': controller.value.isCompleted,
          'positionMs': controller.value.position.inMilliseconds,
          'durationMs': controller.value.duration.inMilliseconds,
        });
      }
    }) as StreamSubscription<void>?;

    if (autoPlay) {
      await controller.play();
    }

    _players[playerId] =
        _ManagedPlayer(controller: controller, listener: listener);

    BridgeLogger.info('VideoPlayer', 'Created: $playerId');

    return {
      'playerId': playerId,
      'initialized': true,
      'durationMs': controller.value.duration.inMilliseconds,
      'width': controller.value.size.width,
      'height': controller.value.size.height,
    };
  }

  vp.VideoPlayerController _getController(String playerId) {
    final managed = _players[playerId];
    if (managed == null) throw StateError('Player "$playerId" not found');
    return managed.controller;
  }

  Future<Map<String, dynamic>> _play(Map<String, dynamic> args) async {
    final c = _getController(args['playerId'] as String);
    await c.play();
    return {'playing': true};
  }

  Future<Map<String, dynamic>> _pause(Map<String, dynamic> args) async {
    final c = _getController(args['playerId'] as String);
    await c.pause();
    return {'paused': true};
  }

  Future<Map<String, dynamic>> _seekTo(Map<String, dynamic> args) async {
    final c = _getController(args['playerId'] as String);
    final ms = (args['positionMs'] as num).toInt();
    await c.seekTo(Duration(milliseconds: ms));
    return {'seeked': true, 'positionMs': ms};
  }

  Future<Map<String, dynamic>> _setVolume(Map<String, dynamic> args) async {
    final c = _getController(args['playerId'] as String);
    final v = (args['volume'] as num).toDouble().clamp(0.0, 1.0);
    await c.setVolume(v);
    return {'volume': v};
  }

  Future<Map<String, dynamic>> _setPlaybackSpeed(
      Map<String, dynamic> args) async {
    final c = _getController(args['playerId'] as String);
    final s = (args['speed'] as num).toDouble().clamp(0.25, 4.0);
    await c.setPlaybackSpeed(s);
    return {'speed': s};
  }

  Future<Map<String, dynamic>> _setLooping(Map<String, dynamic> args) async {
    final c = _getController(args['playerId'] as String);
    final l = args['looping'] as bool? ?? false;
    await c.setLooping(l);
    return {'looping': l};
  }

  Map<String, dynamic> _getPosition(Map<String, dynamic> args) {
    final c = _getController(args['playerId'] as String);
    return {
      'positionMs': c.value.position.inMilliseconds,
      'positionSec': c.value.position.inSeconds,
    };
  }

  Map<String, dynamic> _getDuration(Map<String, dynamic> args) {
    final c = _getController(args['playerId'] as String);
    return {
      'durationMs': c.value.duration.inMilliseconds,
      'durationSec': c.value.duration.inSeconds,
    };
  }

  Map<String, dynamic> _getState(Map<String, dynamic> args) {
    final c = _getController(args['playerId'] as String);
    final v = c.value;
    return {
      'isPlaying': v.isPlaying,
      'isBuffering': v.isBuffering,
      'isCompleted': v.isCompleted,
      'isInitialized': v.isInitialized,
      'positionMs': v.position.inMilliseconds,
      'durationMs': v.duration.inMilliseconds,
      'volume': v.volume,
      'playbackSpeed': v.playbackSpeed,
      'isLooping': v.isLooping,
      'width': v.size.width,
      'height': v.size.height,
    };
  }

  Future<Map<String, dynamic>> _disposePlayer(Map<String, dynamic> args) async {
    final playerId = args['playerId'] as String;
    final managed = _players.remove(playerId);
    if (managed != null) {
      managed.listener?.cancel();
      await managed.controller.dispose();
      return {'disposed': true, 'playerId': playerId};
    }
    return {'disposed': false, 'reason': 'not_found'};
  }

  Future<Map<String, dynamic>> _disposeAll() async {
    final count = _players.length;
    for (final p in _players.values) {
      p.listener?.cancel();
      await p.controller.dispose();
    }
    _players.clear();
    return {'disposed': count};
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    final needsPlayerId = [
      'play',
      'pause',
      'seekTo',
      'setVolume',
      'setPlaybackSpeed',
      'setLooping',
      'getPosition',
      'getDuration',
      'getState',
      'dispose',
    ];

    if (needsPlayerId.contains(method)) {
      if (args['playerId'] is! String || (args['playerId'] as String).isEmpty) {
        return ValidationResult.invalid('playerId is required');
      }
    }

    if (method == 'create') {
      final url = args['url'];
      final path = args['path'];
      if ((url == null || url.toString().isEmpty) &&
          (path == null || path.toString().isEmpty)) {
        return ValidationResult.invalid('url or path is required');
      }
    }

    return ValidationResult.valid();
  }
}

class _ManagedPlayer {
  final vp.VideoPlayerController controller;
  final StreamSubscription<void>? listener;

  _ManagedPlayer({required this.controller, this.listener});
}
