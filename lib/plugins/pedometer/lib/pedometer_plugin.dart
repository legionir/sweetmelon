import 'dart:async';

import 'package:pedometer/pedometer.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef PedometerEventEmitter = Future<void> Function(
    String event, dynamic data);

class PedometerPlugin extends Plugin {
  final PedometerEventEmitter? eventEmitter;

  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;
  bool _tracking = false;
  int _lastStepCount = 0;
  String _lastStatus = 'unknown';

  PedometerPlugin({this.eventEmitter});

  @override
  String get name => 'pedometer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Step counter and pedestrian status plugin';

  @override
  List<String> get supportedMethods => [
        'startTracking',
        'stopTracking',
        'getStepCount',
        'getStatus',
        'isTracking',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    await _stopTracking();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'startTracking':
        return _startTracking();
      case 'stopTracking':
        return _stopTracking();
      case 'getStepCount':
        return {'steps': _lastStepCount};
      case 'getStatus':
        return {'status': _lastStatus};
      case 'isTracking':
        return {'tracking': _tracking};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'tracking': _tracking,
          'lastStepCount': _lastStepCount,
          'lastStatus': _lastStatus,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _startTracking() async {
    if (_tracking) {
      return {'started': true, 'alreadyTracking': true};
    }

    _stepSub = Pedometer.stepCountStream.listen(
      (event) {
        _lastStepCount = event.steps;
        eventEmitter?.call('pedometer.step', {
          'steps': event.steps,
          'timestamp': event.timeStamp.toIso8601String(),
        });
      },
      onError: (error) {
        BridgeLogger.error('Pedometer', 'Step count error: $error');
        eventEmitter?.call('pedometer.error', {
          'type': 'stepCount',
          'message': error.toString(),
        });
      },
    );

    _statusSub = Pedometer.pedestrianStatusStream.listen(
      (event) {
        _lastStatus = event.status;
        eventEmitter?.call('pedometer.status', {
          'status': event.status,
          'timestamp': event.timeStamp.toIso8601String(),
        });
      },
      onError: (error) {
        BridgeLogger.error('Pedometer', 'Status error: $error');
      },
    );

    _tracking = true;
    BridgeLogger.info('Pedometer', 'Tracking started');

    return {'started': true, 'alreadyTracking': false};
  }

  Future<Map<String, dynamic>> _stopTracking() async {
    _stepSub?.cancel();
    _statusSub?.cancel();
    _stepSub = null;
    _statusSub = null;
    _tracking = false;

    return {'stopped': true, 'lastSteps': _lastStepCount};
  }
}
