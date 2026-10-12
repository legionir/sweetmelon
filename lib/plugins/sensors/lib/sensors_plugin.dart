import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef SensorEventEmitter = Future<void> Function(String event, dynamic data);

class SensorsPlugin extends Plugin {
  final SensorEventEmitter? eventEmitter;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magnetSub;
  StreamSubscription<UserAccelerometerEvent>? _userAccelSub;

  final Map<String, bool> _activeStreams = {};

  SensorsPlugin({this.eventEmitter});

  @override
  String get name => 'sensors';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Device sensors: accelerometer, gyroscope, magnetometer';

  @override
  List<String> get supportedMethods => [
        'startAccelerometer',
        'stopAccelerometer',
        'startGyroscope',
        'stopGyroscope',
        'startMagnetometer',
        'stopMagnetometer',
        'startUserAccelerometer',
        'stopUserAccelerometer',
        'stopAll',
        'getActiveStreams',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    await _cancelAll();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'startAccelerometer':
        return _startAccelerometer(args);
      case 'stopAccelerometer':
        return _stopAccelerometer();
      case 'startGyroscope':
        return _startGyroscope(args);
      case 'stopGyroscope':
        return _stopGyroscope();
      case 'startMagnetometer':
        return _startMagnetometer(args);
      case 'stopMagnetometer':
        return _stopMagnetometer();
      case 'startUserAccelerometer':
        return _startUserAccelerometer(args);
      case 'stopUserAccelerometer':
        return _stopUserAccelerometer();
      case 'stopAll':
        return _stopAll();
      case 'getActiveStreams':
        return {'streams': _activeStreams};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'activeStreams': _activeStreams,
          'availableSensors': [
            'accelerometer',
            'gyroscope',
            'magnetometer',
            'userAccelerometer',
          ],
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Duration _parseInterval(Map<String, dynamic> args) {
    final ms = (args['intervalMs'] as num?)?.toInt() ?? 100;
    return Duration(milliseconds: ms.clamp(16, 5000));
  }

  // ── Accelerometer ──

  Map<String, dynamic> _startAccelerometer(Map<String, dynamic> args) {
    if (_activeStreams['accelerometer'] == true) {
      return {'started': true, 'alreadyStarted': true};
    }

    final interval = _parseInterval(args);

    _accelSub = accelerometerEventStream(
      samplingPeriod: interval,
    ).listen((event) {
      eventEmitter?.call('sensors.accelerometer', {
        'x': event.x,
        'y': event.y,
        'z': event.z,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    _activeStreams['accelerometer'] = true;
    return {'started': true, 'sensor': 'accelerometer'};
  }

  Map<String, dynamic> _stopAccelerometer() {
    _accelSub?.cancel();
    _accelSub = null;
    _activeStreams.remove('accelerometer');
    return {'stopped': true, 'sensor': 'accelerometer'};
  }

  // ── Gyroscope ──

  Map<String, dynamic> _startGyroscope(Map<String, dynamic> args) {
    if (_activeStreams['gyroscope'] == true) {
      return {'started': true, 'alreadyStarted': true};
    }

    final interval = _parseInterval(args);

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: interval,
    ).listen((event) {
      eventEmitter?.call('sensors.gyroscope', {
        'x': event.x,
        'y': event.y,
        'z': event.z,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    _activeStreams['gyroscope'] = true;
    return {'started': true, 'sensor': 'gyroscope'};
  }

  Map<String, dynamic> _stopGyroscope() {
    _gyroSub?.cancel();
    _gyroSub = null;
    _activeStreams.remove('gyroscope');
    return {'stopped': true, 'sensor': 'gyroscope'};
  }

  // ── Magnetometer ──

  Map<String, dynamic> _startMagnetometer(Map<String, dynamic> args) {
    if (_activeStreams['magnetometer'] == true) {
      return {'started': true, 'alreadyStarted': true};
    }

    final interval = _parseInterval(args);

    _magnetSub = magnetometerEventStream(
      samplingPeriod: interval,
    ).listen((event) {
      eventEmitter?.call('sensors.magnetometer', {
        'x': event.x,
        'y': event.y,
        'z': event.z,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    _activeStreams['magnetometer'] = true;
    return {'started': true, 'sensor': 'magnetometer'};
  }

  Map<String, dynamic> _stopMagnetometer() {
    _magnetSub?.cancel();
    _magnetSub = null;
    _activeStreams.remove('magnetometer');
    return {'stopped': true, 'sensor': 'magnetometer'};
  }

  // ── User Accelerometer (without gravity) ──

  Map<String, dynamic> _startUserAccelerometer(Map<String, dynamic> args) {
    if (_activeStreams['userAccelerometer'] == true) {
      return {'started': true, 'alreadyStarted': true};
    }

    final interval = _parseInterval(args);

    _userAccelSub = userAccelerometerEventStream(
      samplingPeriod: interval,
    ).listen((event) {
      eventEmitter?.call('sensors.userAccelerometer', {
        'x': event.x,
        'y': event.y,
        'z': event.z,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    _activeStreams['userAccelerometer'] = true;
    return {'started': true, 'sensor': 'userAccelerometer'};
  }

  Map<String, dynamic> _stopUserAccelerometer() {
    _userAccelSub?.cancel();
    _userAccelSub = null;
    _activeStreams.remove('userAccelerometer');
    return {'stopped': true, 'sensor': 'userAccelerometer'};
  }

  // ── Stop All ──

  Future<void> _cancelAll() async {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magnetSub?.cancel();
    _userAccelSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _magnetSub = null;
    _userAccelSub = null;
    _activeStreams.clear();
  }

  Map<String, dynamic> _stopAll() {
    final count = _activeStreams.length;
    _cancelAll();
    return {'stopped': count};
  }
}
