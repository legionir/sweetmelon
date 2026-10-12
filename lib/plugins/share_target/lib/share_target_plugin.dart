import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef ShareTargetEventEmitter = Future<void> Function(
    String event, dynamic data);

class ShareTargetPlugin extends Plugin {
  final ShareTargetEventEmitter? eventEmitter;

  Map<String, dynamic>? _lastSharedData;
  bool _listening = false;

  static const _channel = MethodChannel('sweetmelon/share_target');

  ShareTargetPlugin({this.eventEmitter});

  @override
  String get name => 'shareTarget';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Receive shared content from other apps';

  @override
  List<String> get supportedMethods => [
        'startListening',
        'stopListening',
        'getLastShared',
        'clearLastShared',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSharedText':
          _handleSharedText(call.arguments as Map<dynamic, dynamic>);
          break;
        case 'onSharedFiles':
          _handleSharedFiles(call.arguments as Map<dynamic, dynamic>);
          break;
      }
      return null;
    });

    // Check initial shared data
    try {
      final initial = await _channel.invokeMethod('getInitialSharedData');
      if (initial != null) {
        _handleSharedData(Map<String, dynamic>.from(initial));
      }
    } catch (_) {}
  }

  @override
  Future<void> onDispose() async {
    _channel.setMethodCallHandler(null);
    _listening = false;
  }

  void _handleSharedText(Map<dynamic, dynamic> data) {
    final shared = {
      'type': 'text',
      'text': data['text'],
      'title': data['title'],
      'timestamp': DateTime.now().toIso8601String(),
    };

    _handleSharedData(shared);
  }

  void _handleSharedFiles(Map<dynamic, dynamic> data) {
    final paths = data['paths'] as List<dynamic>?;

    final shared = {
      'type': 'files',
      'paths': paths?.map((p) => p.toString()).toList() ?? [],
      'mimeType': data['mimeType'],
      'text': data['text'],
      'timestamp': DateTime.now().toIso8601String(),
    };

    _handleSharedData(shared);
  }

  void _handleSharedData(Map<String, dynamic> data) {
    _lastSharedData = data;

    BridgeLogger.info(
      'ShareTarget',
      'Received shared content: ${data['type']}',
    );

    if (_listening && eventEmitter != null) {
      eventEmitter!('shareTarget.received', data);
    }
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'startListening':
        _listening = true;
        // اگه قبلاً چیزی share شده بود، emit کن
        if (_lastSharedData != null && eventEmitter != null) {
          eventEmitter!('shareTarget.received', _lastSharedData);
        }
        return {'listening': true};

      case 'stopListening':
        _listening = false;
        return {'listening': false};

      case 'getLastShared':
        return _lastSharedData ?? {'available': false};

      case 'clearLastShared':
        _lastSharedData = null;
        return {'cleared': true};

      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'listening': _listening,
          'hasSharedData': _lastSharedData != null,
        };

      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }
}
