import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef TextZoomEventEmitter = Future<void> Function(
    String event, dynamic data);

class TextZoomPlugin extends Plugin {
  final TextZoomEventEmitter? eventEmitter;

  double _currentZoom = 100;
  static const double _minZoom = 50;
  static const double _maxZoom = 300;

  TextZoomPlugin({this.eventEmitter});

  @override
  String get name => 'textZoom';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'WebView text zoom for accessibility';

  @override
  List<String> get supportedMethods => [
        'get',
        'set',
        'increase',
        'decrease',
        'reset',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'get':
        return {'zoom': _currentZoom};
      case 'set':
        return _setZoom(args);
      case 'increase':
        return _increase(args);
      case 'decrease':
        return _decrease(args);
      case 'reset':
        return _setZoom({'zoom': 100});
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'zoom': _currentZoom,
          'minZoom': _minZoom,
          'maxZoom': _maxZoom,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _setZoom(Map<String, dynamic> args) async {
    final zoom = (args['zoom'] as num).toDouble().clamp(_minZoom, _maxZoom);
    _currentZoom = zoom;

    eventEmitter?.call('textZoom.changed', {
      'zoom': _currentZoom,
      'timestamp': DateTime.now().toIso8601String(),
    });

    BridgeLogger.info('TextZoom', 'Zoom set to: $_currentZoom%');

    return {'zoom': _currentZoom};
  }

  Future<Map<String, dynamic>> _increase(Map<String, dynamic> args) async {
    final step = (args['step'] as num?)?.toDouble() ?? 10;
    return _setZoom({'zoom': _currentZoom + step});
  }

  Future<Map<String, dynamic>> _decrease(Map<String, dynamic> args) async {
    final step = (args['step'] as num?)?.toDouble() ?? 10;
    return _setZoom({'zoom': _currentZoom - step});
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'set') {
      final zoom = args['zoom'];
      if (zoom is! num) {
        return ValidationResult.invalid('zoom (number, 50-300) is required');
      }
    }
    return ValidationResult.valid();
  }
}
