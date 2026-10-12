import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef BgGeoEventEmitter = Future<void> Function(String event, dynamic data);

class BackgroundGeolocationPlugin extends Plugin {
  final BgGeoEventEmitter? eventEmitter;

  StreamSubscription<Position>? _positionSub;
  bool _tracking = false;
  Position? _lastPosition;
  int _updateCount = 0;
  final List<Map<String, dynamic>> _history = [];

  BackgroundGeolocationPlugin({this.eventEmitter});

  @override
  String get name => 'backgroundGeolocation';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Background geolocation tracking plugin';

  @override
  List<String> get requiredPermissions => ['location'];

  @override
  List<String> get supportedMethods => [
        'startTracking',
        'stopTracking',
        'getLastPosition',
        'getHistory',
        'clearHistory',
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
        return _startTracking(args);
      case 'stopTracking':
        return _stopTracking();
      case 'getLastPosition':
        return _getLastPosition();
      case 'getHistory':
        return _getHistory(args);
      case 'clearHistory':
        return _clearHistory();
      case 'isTracking':
        return {'tracking': _tracking};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'tracking': _tracking,
          'updateCount': _updateCount,
          'historyCount': _history.length,
          'lastPosition':
              _lastPosition != null ? _positionToMap(_lastPosition!) : null,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _startTracking(Map<String, dynamic> args) async {
    if (_tracking) {
      return {'started': true, 'alreadyTracking': true};
    }

    final accuracy = _parseAccuracy(args['accuracy'] as String? ?? 'high');
    final distanceFilter = (args['distanceFilter'] as num?)?.toInt() ?? 10;
    final intervalMs = (args['intervalMs'] as num?)?.toInt();
    final maxHistory = (args['maxHistory'] as num?)?.toInt() ?? 500;

    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      timeLimit: intervalMs != null ? Duration(milliseconds: intervalMs) : null,
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        _lastPosition = position;
        _updateCount++;

        final posMap = _positionToMap(position);

        // ذخیره در history
        _history.add(posMap);
        if (_history.length > maxHistory) {
          _history.removeAt(0);
        }

        if (eventEmitter != null) {
          eventEmitter!('bgGeo.position', posMap);
        }
      },
      onError: (error) {
        BridgeLogger.error('BgGeo', 'Tracking error: $error');
        if (eventEmitter != null) {
          eventEmitter!('bgGeo.error', {
            'message': error.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      },
    );

    _tracking = true;

    BridgeLogger.info(
      'BgGeo',
      'Tracking started (accuracy: $accuracy, distance: ${distanceFilter}m)',
    );

    return {
      'started': true,
      'alreadyTracking': false,
      'accuracy': accuracy.toString(),
      'distanceFilter': distanceFilter,
    };
  }

  Future<Map<String, dynamic>> _stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _tracking = false;

    return {
      'stopped': true,
      'totalUpdates': _updateCount,
    };
  }

  Map<String, dynamic> _getLastPosition() {
    if (_lastPosition == null) {
      return {'available': false};
    }

    return {
      'available': true,
      ..._positionToMap(_lastPosition!),
    };
  }

  Map<String, dynamic> _getHistory(Map<String, dynamic> args) {
    final limit = (args['limit'] as num?)?.toInt();
    final since = (args['sinceMs'] as num?)?.toInt();

    var result = List<Map<String, dynamic>>.from(_history);

    if (since != null) {
      final sinceDate = DateTime.fromMillisecondsSinceEpoch(since);
      result = result.where((p) {
        final ts = DateTime.parse(p['timestamp'] as String);
        return ts.isAfter(sinceDate);
      }).toList();
    }

    if (limit != null && limit > 0 && result.length > limit) {
      result = result.sublist(result.length - limit);
    }

    return {
      'positions': result,
      'count': result.length,
      'totalHistory': _history.length,
    };
  }

  Map<String, dynamic> _clearHistory() {
    final count = _history.length;
    _history.clear();
    _updateCount = 0;
    return {'cleared': count};
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

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'startTracking') {
      final accuracy = args['accuracy'];
      if (accuracy != null && accuracy is! String) {
        return ValidationResult.invalid('accuracy must be a string');
      }
    }
    return ValidationResult.valid();
  }
}
