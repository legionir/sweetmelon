import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef FgEventEmitter = Future<void> Function(String event, dynamic data);

class ForegroundServicePlugin extends Plugin {
  final FgEventEmitter? eventEmitter;

  bool _running = false;
  String? _currentTitle;
  String? _currentBody;
  Timer? _updateTimer;

  static const _channel = MethodChannel('sweetmelon/foreground_service');

  ForegroundServicePlugin({this.eventEmitter});

  @override
  String get name => 'foregroundService';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Android foreground service for persistent tasks';

  @override
  List<String> get supportedMethods => [
        'start',
        'stop',
        'update',
        'isRunning',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'start':
        return _start(args);
      case 'stop':
        return _stop();
      case 'update':
        return _update(args);
      case 'isRunning':
        return {'running': _running};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'running': _running,
          'title': _currentTitle,
          'body': _currentBody,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _start(Map<String, dynamic> args) async {
    if (_running) {
      return {'started': true, 'alreadyRunning': true};
    }

    final title = args['title'] as String? ?? 'App is running';
    final body = args['body'] as String? ?? 'Tap to return to app';
    final channelId = args['channelId'] as String? ?? 'foreground_service';
    final channelName = args['channelName'] as String? ?? 'Foreground Service';

    _currentTitle = title;
    _currentBody = body;

    try {
      await _channel.invokeMethod('startService', {
        'title': title,
        'body': body,
        'channelId': channelId,
        'channelName': channelName,
      });

      _running = true;

      BridgeLogger.info('ForegroundService', 'Service started: $title');

      eventEmitter?.call('foregroundService.started', {
        'title': title,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return {'started': true, 'alreadyRunning': false};
    } catch (e) {
      BridgeLogger.error('ForegroundService', 'Start failed: $e');

      // Fallback: شبیه‌سازی بدون native channel
      _running = true;
      return {
        'started': true,
        'native': false,
        'fallback': true,
      };
    }
  }

  Future<Map<String, dynamic>> _stop() async {
    if (!_running) {
      return {'stopped': false, 'reason': 'not_running'};
    }

    _updateTimer?.cancel();

    try {
      await _channel.invokeMethod('stopService');
    } catch (_) {}

    _running = false;
    _currentTitle = null;
    _currentBody = null;

    BridgeLogger.info('ForegroundService', 'Service stopped');

    eventEmitter?.call('foregroundService.stopped', {
      'timestamp': DateTime.now().toIso8601String(),
    });

    return {'stopped': true};
  }

  Future<Map<String, dynamic>> _update(Map<String, dynamic> args) async {
    if (!_running) {
      return {'updated': false, 'reason': 'not_running'};
    }

    final title = args['title'] as String?;
    final body = args['body'] as String?;

    if (title != null) _currentTitle = title;
    if (body != null) _currentBody = body;

    try {
      await _channel.invokeMethod('updateNotification', {
        'title': _currentTitle,
        'body': _currentBody,
      });
    } catch (_) {}

    return {
      'updated': true,
      'title': _currentTitle,
      'body': _currentBody,
    };
  }

  @override
  Future<void> onDispose() async {
    if (_running) {
      await _stop();
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'start') {
      final title = args['title'];
      if (title != null && title is! String) {
        return ValidationResult.invalid('title must be a string');
      }
    }
    return ValidationResult.valid();
  }
}
