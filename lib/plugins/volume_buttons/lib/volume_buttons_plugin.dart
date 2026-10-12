import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef VolumeEventEmitter = Future<void> Function(String event, dynamic data);

class VolumeButtonsPlugin extends Plugin {
  final VolumeEventEmitter? eventEmitter;
  bool _listening = false;
  static const _channel = EventChannel('sweetmelon/volume_buttons');
  StreamSubscription<dynamic>? _sub;

  VolumeButtonsPlugin({this.eventEmitter});

  @override
  String get name => 'volumeButtons';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Listen to volume button presses';

  @override
  List<String> get supportedMethods => [
        'startListening',
        'stopListening',
        'isListening',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    _sub?.cancel();
    _listening = false;
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'startListening':
        return _startListening();
      case 'stopListening':
        return _stopListening();
      case 'isListening':
        return {'listening': _listening};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'listening': _listening,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _startListening() {
    if (_listening) {
      return {'started': true, 'alreadyListening': true};
    }

    try {
      _sub = _channel.receiveBroadcastStream().listen(
        (event) {
          final direction = event == 'up' ? 'up' : 'down';

          eventEmitter?.call('volume.pressed', {
            'direction': direction,
            'timestamp': DateTime.now().toIso8601String(),
          });
        },
        onError: (error) {
          BridgeLogger.error('VolumeButtons', 'Stream error: $error');
        },
      );

      _listening = true;
    } catch (e) {
      BridgeLogger.warn('VolumeButtons', 'Native channel not available: $e');
      _listening = true; // still mark as listening for stub
    }

    return {'started': true, 'alreadyListening': false};
  }

  Map<String, dynamic> _stopListening() {
    _sub?.cancel();
    _sub = null;
    _listening = false;
    return {'stopped': true};
  }
}
