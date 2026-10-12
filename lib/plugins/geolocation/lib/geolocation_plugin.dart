import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

typedef PluginEventEmitter = Future<void> Function(String event, dynamic data);

class GeolocationPlugin extends Plugin {
  StreamSubscription<Position>? _positionStream;
  final PluginEventEmitter? eventEmitter;

  GeolocationPlugin({this.eventEmitter});

  @override
  String get name => 'geolocation';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Geolocation and GPS plugin';

  @override
  bool get cacheable => false;

  @override
  List<String> get supportedMethods => [
        'getCurrentPosition',
        'watchPosition',
        'clearWatch',
        'checkPermission',
        'requestPermission',
        'isLocationEnabled',
      ];

  @override
  List<String> get requiredPermissions => ['location'];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getCurrentPosition':
        return _getCurrentPosition(args);
      case 'watchPosition':
        return _watchPosition(args);
      case 'clearWatch':
        return _clearWatch();
      case 'checkPermission':
        return _checkPermission();
      case 'requestPermission':
        return _requestPermission();
      case 'isLocationEnabled':
        return _isLocationEnabled();
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _getCurrentPosition(
    Map<String, dynamic> args,
  ) async {
    final accuracy = _parseAccuracy(args['accuracy'] as String? ?? 'high');

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: accuracy,
    );

    return _positionToMap(position);
  }

  Future<String> _watchPosition(Map<String, dynamic> args) async {
    final accuracy = _parseAccuracy(args['accuracy'] as String? ?? 'high');
    final distanceFilter = (args['distanceFilter'] as num?)?.toDouble() ?? 10;

    await _clearWatch();

    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter.toInt(),
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        final data = _positionToMap(position);

        if (eventEmitter != null) {
          eventEmitter!('geolocation.position', data);
        } else {
          BridgeLogger.warn(
            'Geolocation',
            'No event emitter set, position update dropped',
          );
        }
      },
      onError: (error) {
        BridgeLogger.error('Geolocation', 'Watch error: $error');

        if (eventEmitter != null) {
          eventEmitter!('geolocation.error', {
            'message': error.toString(),
          });
        }
      },
    );

    return 'watch_started';
  }

  Future<String> _clearWatch() async {
    await _positionStream?.cancel();
    _positionStream = null;
    return 'watch_cleared';
  }

  Future<String> _checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission.name;
  }

  Future<String> _requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission.name;
  }

  Future<bool> _isLocationEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  LocationAccuracy _parseAccuracy(String accuracy) {
    switch (accuracy) {
      case 'lowest':
        return LocationAccuracy.lowest;
      case 'low':
        return LocationAccuracy.low;
      case 'medium':
        return LocationAccuracy.medium;
      case 'high':
        return LocationAccuracy.high;
      case 'best':
        return LocationAccuracy.best;
      case 'bestForNavigation':
        return LocationAccuracy.bestForNavigation;
      default:
        return LocationAccuracy.high;
    }
  }

  Map<String, dynamic> _positionToMap(Position position) {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'altitude': position.altitude,
      'accuracy': position.accuracy,
      'heading': position.heading,
      'speed': position.speed,
      'speedAccuracy': position.speedAccuracy,
      'timestamp': position.timestamp.toIso8601String(),
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'getCurrentPosition':
      case 'watchPosition':
        return _validatePositionArgs(args);
      default:
        return ValidationResult.valid();
    }
  }

  ValidationResult _validatePositionArgs(Map<String, dynamic> args) {
    final accuracy = args['accuracy'];
    if (accuracy != null && accuracy is! String) {
      return ValidationResult.invalid('accuracy must be a string');
    }

    const validAccuracies = [
      'lowest',
      'low',
      'medium',
      'high',
      'best',
      'bestForNavigation',
    ];
    if (accuracy != null && !validAccuracies.contains(accuracy)) {
      return ValidationResult.invalid(
        'accuracy must be one of: ${validAccuracies.join(", ")}',
      );
    }

    final distanceFilter = args['distanceFilter'];
    if (distanceFilter != null && distanceFilter is! num) {
      return ValidationResult.invalid('distanceFilter must be a number');
    }

    return ValidationResult.valid();
  }

  @override
  Future<void> onDispose() async {
    await _clearWatch();
  }
}
