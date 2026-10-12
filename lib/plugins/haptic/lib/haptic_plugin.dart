import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class HapticPlugin extends Plugin {
  @override
  String get name => 'haptic';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Haptic feedback and vibration plugin';

  @override
  List<String> get supportedMethods => [
        'lightImpact',
        'mediumImpact',
        'heavyImpact',
        'selectionClick',
        'vibrate',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'lightImpact':
        await HapticFeedback.lightImpact();
        return {'type': 'light', 'triggered': true};

      case 'mediumImpact':
        await HapticFeedback.mediumImpact();
        return {'type': 'medium', 'triggered': true};

      case 'heavyImpact':
        await HapticFeedback.heavyImpact();
        return {'type': 'heavy', 'triggered': true};

      case 'selectionClick':
        await HapticFeedback.selectionClick();
        return {'type': 'selection', 'triggered': true};

      case 'vibrate':
        await HapticFeedback.vibrate();
        return {'type': 'vibrate', 'triggered': true};

      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'supportedTypes': [
            'lightImpact',
            'mediumImpact',
            'heavyImpact',
            'selectionClick',
            'vibrate',
          ],
        };

      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }
}
