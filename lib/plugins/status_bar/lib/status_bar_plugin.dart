import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class StatusBarPlugin extends Plugin {
  SystemUiOverlayStyle _currentStyle = SystemUiOverlayStyle.light;

  @override
  String get name => 'statusBar';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Status bar and system UI control plugin';

  @override
  List<String> get supportedMethods => [
        'setStyle',
        'setColor',
        'show',
        'hide',
        'setFullscreen',
        'exitFullscreen',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'setStyle':
        return _setStyle(args);
      case 'setColor':
        return _setColor(args);
      case 'show':
        return _show();
      case 'hide':
        return _hide();
      case 'setFullscreen':
        return _setFullscreen();
      case 'exitFullscreen':
        return _exitFullscreen();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'supportedStyles': ['light', 'dark'],
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _setStyle(Map<String, dynamic> args) {
    final style = args['style'] as String? ?? 'light';

    if (style == 'dark') {
      _currentStyle = SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: _parseColor(args['backgroundColor']),
      );
    } else {
      _currentStyle = SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _parseColor(args['backgroundColor']),
      );
    }

    SystemChrome.setSystemUIOverlayStyle(_currentStyle);

    return {'style': style, 'applied': true};
  }

  Map<String, dynamic> _setColor(Map<String, dynamic> args) {
    final color = _parseColor(args['color']) ?? const Color(0x00000000);
    final navColor = _parseColor(args['navigationBarColor']);

    _currentStyle = _currentStyle.copyWith(
      statusBarColor: color,
      systemNavigationBarColor: navColor,
    );

    SystemChrome.setSystemUIOverlayStyle(_currentStyle);

    return {'applied': true};
  }

  Map<String, dynamic> _show() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    return {'visible': true};
  }

  Map<String, dynamic> _hide() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [],
    );
    return {'visible': false};
  }

  Map<String, dynamic> _setFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    return {'fullscreen': true};
  }

  Map<String, dynamic> _exitFullscreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    return {'fullscreen': false};
  }

  Color? _parseColor(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      var hex = value.replaceAll('#', '').trim();
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) {
        final intColor = int.tryParse(hex, radix: 16);
        if (intColor != null) return Color(intColor);
      }
    }

    if (value is int) {
      return Color(value);
    }

    return null;
  }
}
