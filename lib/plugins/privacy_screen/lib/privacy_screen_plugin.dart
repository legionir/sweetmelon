import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class PrivacyScreenPlugin extends Plugin {
  bool _enabled = false;
  static const _channel = MethodChannel('sweetmelon/privacy_screen');

  @override
  String get name => 'privacyScreen';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Prevent screenshots and hide content in app switcher';

  @override
  List<String> get supportedMethods => [
        'enable',
        'disable',
        'isEnabled',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'enable':
        return _enable();
      case 'disable':
        return _disable();
      case 'isEnabled':
        return {'enabled': _enabled};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'enabled': _enabled,
          'platform': Platform.operatingSystem,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _enable() async {
    if (_enabled) {
      return {'enabled': true, 'alreadyEnabled': true};
    }

    try {
      // Android: FLAG_SECURE
      if (Platform.isAndroid) {
        await _channel.invokeMethod('enablePrivacy');
      }

      _enabled = true;
      BridgeLogger.info('PrivacyScreen', 'Privacy screen enabled');

      return {'enabled': true, 'alreadyEnabled': false};
    } catch (e) {
      BridgeLogger.error('PrivacyScreen', 'Enable failed: $e');
      return {'enabled': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _disable() async {
    if (!_enabled) {
      return {'enabled': false, 'alreadyDisabled': true};
    }

    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('disablePrivacy');
      }

      _enabled = false;
      BridgeLogger.info('PrivacyScreen', 'Privacy screen disabled');

      return {'enabled': false, 'alreadyDisabled': false};
    } catch (e) {
      BridgeLogger.error('PrivacyScreen', 'Disable failed: $e');
      return {'enabled': _enabled, 'error': e.toString()};
    }
  }

  @override
  Future<void> onDispose() async {
    if (_enabled) {
      await _disable();
    }
  }
}
