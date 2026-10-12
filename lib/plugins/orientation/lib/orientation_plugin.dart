import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class OrientationPlugin extends Plugin {
  @override
  String get name => 'orientation';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Screen orientation control plugin';

  @override
  List<String> get supportedMethods => [
        'lock',
        'unlock',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'lock':
        return _lock(args);
      case 'unlock':
        return _unlock();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'supportedOrientations': [
            'portrait',
            'portraitUp',
            'portraitDown',
            'landscape',
            'landscapeLeft',
            'landscapeRight',
          ],
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _lock(Map<String, dynamic> args) async {
    final orientation = args['orientation'] as String? ?? 'portrait';

    final orientations = _parseOrientations(orientation);

    await SystemChrome.setPreferredOrientations(orientations);

    return {'locked': true, 'orientation': orientation};
  }

  Future<Map<String, dynamic>> _unlock() async {
    await SystemChrome.setPreferredOrientations(
      DeviceOrientation.values,
    );

    return {'locked': false, 'orientation': 'all'};
  }

  List<DeviceOrientation> _parseOrientations(String orientation) {
    switch (orientation) {
      case 'portrait':
        return [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ];
      case 'portraitUp':
        return [DeviceOrientation.portraitUp];
      case 'portraitDown':
        return [DeviceOrientation.portraitDown];
      case 'landscape':
        return [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
      case 'landscapeLeft':
        return [DeviceOrientation.landscapeLeft];
      case 'landscapeRight':
        return [DeviceOrientation.landscapeRight];
      default:
        return DeviceOrientation.values;
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'lock') {
      final orientation = args['orientation'];
      if (orientation != null && orientation is! String) {
        return ValidationResult.invalid('orientation must be a string');
      }
    }
    return ValidationResult.valid();
  }
}
