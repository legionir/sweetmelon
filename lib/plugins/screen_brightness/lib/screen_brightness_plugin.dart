import 'package:screen_brightness/screen_brightness.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class ScreenBrightnessPlugin extends Plugin {
  @override
  String get name => 'screenBrightness';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Control device screen brightness';

  @override
  List<String> get supportedMethods => [
        'get',
        'set',
        'reset',
        'getSystem',
        'setAutoReset',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'get':
        return _getBrightness();
      case 'set':
        return _setBrightness(args);
      case 'reset':
        return _resetBrightness();
      case 'getSystem':
        return _getSystemBrightness();
      case 'setAutoReset':
        return _setAutoReset(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _getBrightness() async {
    try {
      final brightness = await ScreenBrightness().application;
      return {'brightness': brightness};
    } catch (e) {
      return {'brightness': -1, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _setBrightness(Map<String, dynamic> args) async {
    final value = (args['brightness'] as num).toDouble().clamp(0.0, 1.0);

    try {
      await ScreenBrightness().setApplicationScreenBrightness(value);
      BridgeLogger.info('ScreenBrightness', 'Set to: $value');
      return {'brightness': value, 'set': true};
    } catch (e) {
      return {'set': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _resetBrightness() async {
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
      return {'reset': true};
    } catch (e) {
      return {'reset': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getSystemBrightness() async {
    try {
      final brightness = await ScreenBrightness().system;
      return {'brightness': brightness};
    } catch (e) {
      return {'brightness': -1, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _setAutoReset(Map<String, dynamic> args) async {
    final enabled = args['enabled'] as bool? ?? true;
    try {
      await ScreenBrightness().setAutoReset(enabled);
      return {'autoReset': enabled};
    } catch (e) {
      return {'autoReset': false, 'error': e.toString()};
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'set') {
      final b = args['brightness'];
      if (b is! num) {
        return ValidationResult.invalid('brightness (0.0-1.0) is required');
      }
    }
    return ValidationResult.valid();
  }
}
