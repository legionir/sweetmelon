import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class KioskModePlugin extends Plugin {
  bool _enabled = false;

  @override
  String get name => 'kioskMode';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Lock device into kiosk mode';

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
        return {'name': name, 'version': version, 'enabled': _enabled};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _enable() async {
    if (_enabled) {
      return {'enabled': true, 'alreadyEnabled': true};
    }

    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Lock orientation
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _enabled = true;
    BridgeLogger.info('KioskMode', 'Kiosk mode enabled');

    return {'enabled': true, 'alreadyEnabled': false};
  }

  Future<Map<String, dynamic>> _disable() async {
    if (!_enabled) {
      return {'enabled': false, 'alreadyDisabled': true};
    }

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    _enabled = false;
    BridgeLogger.info('KioskMode', 'Kiosk mode disabled');

    return {'enabled': false, 'alreadyDisabled': false};
  }

  @override
  Future<void> onDispose() async {
    if (_enabled) await _disable();
  }
}
