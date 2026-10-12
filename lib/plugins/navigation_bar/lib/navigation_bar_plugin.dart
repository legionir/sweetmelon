import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class NavigationBarPlugin extends Plugin {
  @override
  String get name => 'navigationBar';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Android navigation bar color and visibility control';

  @override
  List<String> get supportedMethods => [
        'setColor',
        'setStyle',
        'show',
        'hide',
        'setTransparent',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'setColor':
        return _setColor(args);
      case 'setStyle':
        return _setStyle(args);
      case 'show':
        return _show();
      case 'hide':
        return _hide();
      case 'setTransparent':
        return _setTransparent();
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _setColor(Map<String, dynamic> args) {
    final colorStr = args['color'] as String;
    final color = _parseColor(colorStr);
    final darkIcons = args['darkIcons'] as bool? ?? false;

    if (color == null) {
      return {'set': false, 'reason': 'invalid_color'};
    }

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: color,
        systemNavigationBarIconBrightness:
            darkIcons ? Brightness.dark : Brightness.light,
      ),
    );

    return {'set': true, 'color': colorStr};
  }

  Map<String, dynamic> _setStyle(Map<String, dynamic> args) {
    final style = args['style'] as String? ?? 'default';

    Brightness iconBrightness;
    Color? bgColor;

    switch (style) {
      case 'light':
        iconBrightness = Brightness.light;
        bgColor = const Color(0xFF000000);
        break;
      case 'dark':
        iconBrightness = Brightness.dark;
        bgColor = const Color(0xFFFFFFFF);
        break;
      default:
        iconBrightness = Brightness.light;
        bgColor = null;
    }

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: bgColor,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
    );

    return {'set': true, 'style': style};
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
      overlays: [SystemUiOverlay.top],
    );
    return {'visible': false};
  }

  Map<String, dynamic> _setTransparent() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0x00000000),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    return {'transparent': true};
  }

  Color? _parseColor(String? value) {
    if (value == null) return null;
    var hex = value.replaceAll('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      final v = int.tryParse(hex, radix: 16);
      if (v != null) return Color(v);
    }
    return null;
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'setColor') {
      final color = args['color'];
      if (color is! String || color.isEmpty) {
        return ValidationResult.invalid('color (#RRGGBB) is required');
      }
    }
    return ValidationResult.valid();
  }
}
