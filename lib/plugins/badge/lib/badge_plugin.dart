import 'package:flutter_app_badger_plus/flutter_app_badger_plus.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class BadgePlugin extends Plugin {
  int _currentCount = 0;

  @override
  String get name => 'badge';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'App icon badge count plugin';

  @override
  List<String> get supportedMethods => [
        'set',
        'clear',
        'increase',
        'decrease',
        'get',
        'isSupported',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'set':
        return _set(args);
      case 'clear':
        return _clear();
      case 'increase':
        return _increase(args);
      case 'decrease':
        return _decrease(args);
      case 'get':
        return {'count': _currentCount};
      case 'isSupported':
        return _isSupported();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'count': _currentCount,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _set(Map<String, dynamic> args) async {
    final count = (args['count'] as num).toInt().clamp(0, 9999);

    try {
      if (count == 0) {
        FlutterAppBadgerPlus.removeBadge();
      } else {
        FlutterAppBadgerPlus.updateBadgeCount(count);
      }
      _currentCount = count;
      return {'count': _currentCount, 'set': true};
    } catch (e) {
      BridgeLogger.error('Badge', 'Set failed: $e');
      return {'set': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _clear() async {
    try {
      FlutterAppBadgerPlus.removeBadge();
      _currentCount = 0;
      return {'count': 0, 'cleared': true};
    } catch (e) {
      return {'cleared': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _increase(Map<String, dynamic> args) async {
    final by = (args['by'] as num?)?.toInt() ?? 1;
    return _set({'count': _currentCount + by});
  }

  Future<Map<String, dynamic>> _decrease(Map<String, dynamic> args) async {
    final by = (args['by'] as num?)?.toInt() ?? 1;
    return _set({'count': (_currentCount - by).clamp(0, 9999)});
  }

  Future<Map<String, dynamic>> _isSupported() async {
    try {
      final supported = await FlutterAppBadgerPlus.isAppBadgeSupported();
      return {'supported': supported};
    } catch (e) {
      return {'supported': false, 'error': e.toString()};
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'set') {
      final count = args['count'];
      if (count is! num) {
        return ValidationResult.invalid('count (number) is required');
      }
    }
    return ValidationResult.valid();
  }
}
