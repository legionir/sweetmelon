import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef ShakeEventEmitter = Future<void> Function(String event, dynamic data);

class ShakeDetectionPlugin extends Plugin {
  final ShakeEventEmitter? eventEmitter;

  StreamSubscription<AccelerometerEvent>? _sub;
  bool _listening = false;
  double _threshold = 15.0;
  int _shakeCount = 0;
  DateTime? _lastShakeTime;
  int _cooldownMs = 1000;

  ShakeDetectionPlugin({this.eventEmitter});

  @override
  String get name => 'shakeDetection';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Detect device shake gesture';

  @override
  List<String> get supportedMethods => [
        'startListening',
        'stopListening',
        'configure',
        'getShakeCount',
        'resetCount',
        'isListening',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    _sub?.cancel();
    _sub = null;
    _listening = false;
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'startListening':
        return _startListening(args);
      case 'stopListening':
        return _stopListening();
      case 'configure':
        return _configure(args);
      case 'getShakeCount':
        return {'count': _shakeCount};
      case 'resetCount':
        _shakeCount = 0;
        return {'reset': true};
      case 'isListening':
        return {'listening': _listening};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'listening': _listening,
          'threshold': _threshold,
          'cooldownMs': _cooldownMs,
          'shakeCount': _shakeCount,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _startListening(Map<String, dynamic> args) {
    if (_listening) {
      return {'started': true, 'alreadyListening': true};
    }

    final threshold = (args['threshold'] as num?)?.toDouble();
    final cooldown = (args['cooldownMs'] as num?)?.toInt();
    if (threshold != null) _threshold = threshold;
    if (cooldown != null) _cooldownMs = cooldown;

    _sub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (magnitude > _threshold) {
        final now = DateTime.now();

        if (_lastShakeTime != null &&
            now.difference(_lastShakeTime!).inMilliseconds < _cooldownMs) {
          return;
        }

        _lastShakeTime = now;
        _shakeCount++;

        BridgeLogger.debug('Shake',
            'Shake detected (magnitude: ${magnitude.toStringAsFixed(1)})');

        eventEmitter?.call('shake.detected', {
          'magnitude': magnitude,
          'count': _shakeCount,
          'timestamp': now.toIso8601String(),
        });
      }
    });

    _listening = true;
    return {'started': true, 'alreadyListening': false};
  }

  Map<String, dynamic> _stopListening() {
    _sub?.cancel();
    _sub = null;
    _listening = false;
    return {'stopped': true};
  }

  Map<String, dynamic> _configure(Map<String, dynamic> args) {
    if (args['threshold'] != null) {
      _threshold = (args['threshold'] as num).toDouble();
    }
    if (args['cooldownMs'] != null) {
      _cooldownMs = (args['cooldownMs'] as num).toInt();
    }
    return {'threshold': _threshold, 'cooldownMs': _cooldownMs};
  }
}
