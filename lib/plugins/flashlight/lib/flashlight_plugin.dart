import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:torch_light/torch_light.dart';

class FlashlightPlugin extends Plugin {
  bool _isOn = false;

  @override
  String get name => 'flashlight';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Flashlight / torch control plugin';

  @override
  List<String> get supportedMethods => [
        'enable',
        'disable',
        'toggle',
        'isAvailable',
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
      case 'toggle':
        return _isOn ? _disable() : _enable();
      case 'isAvailable':
        return _isAvailable();
      case 'isEnabled':
        return {'enabled': _isOn};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'enabled': _isOn,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _enable() async {
    try {
      await TorchLight.enableTorch();
      _isOn = true;
      return {'enabled': true};
    } catch (e) {
      BridgeLogger.error('Flashlight', 'Enable failed: $e');
      return {'enabled': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _disable() async {
    try {
      await TorchLight.disableTorch();
      _isOn = false;
      return {'enabled': false};
    } catch (e) {
      BridgeLogger.error('Flashlight', 'Disable failed: $e');
      return {'enabled': _isOn, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _isAvailable() async {
    try {
      final available = await TorchLight.isTorchAvailable();
      return {'available': available};
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }

  @override
  Future<void> onDispose() async {
    if (_isOn) {
      try {
        await TorchLight.disableTorch();
      } catch (_) {}
      _isOn = false;
    }
  }
}
