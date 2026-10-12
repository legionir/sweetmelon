import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class SafeAreaPlugin extends Plugin {
  @override
  String get name => 'safeArea';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Get safe area insets (notch, status bar, etc)';

  @override
  List<String> get supportedMethods => [
        'getInsets',
        'getScreenInfo',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getInsets':
        return _getInsets();
      case 'getScreenInfo':
        return _getScreenInfo();
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _getInsets() {
    final context = AppContext().context;

    if (context != null) {
      final mediaQuery = MediaQuery.of(context);
      final padding = mediaQuery.padding;
      final viewInsets = mediaQuery.viewInsets;
      final viewPadding = mediaQuery.viewPadding;

      return {
        'padding': {
          'top': padding.top,
          'bottom': padding.bottom,
          'left': padding.left,
          'right': padding.right,
        },
        'viewInsets': {
          'top': viewInsets.top,
          'bottom': viewInsets.bottom,
          'left': viewInsets.left,
          'right': viewInsets.right,
        },
        'viewPadding': {
          'top': viewPadding.top,
          'bottom': viewPadding.bottom,
          'left': viewPadding.left,
          'right': viewPadding.right,
        },
      };
    }

    final view = ui.PlatformDispatcher.instance.views.first;
    final dpr = view.devicePixelRatio;
    final padding = view.padding;
    final viewInsets = view.viewInsets;

    return {
      'padding': {
        'top': padding.top / dpr,
        'bottom': padding.bottom / dpr,
        'left': padding.left / dpr,
        'right': padding.right / dpr,
      },
      'viewInsets': {
        'top': viewInsets.top / dpr,
        'bottom': viewInsets.bottom / dpr,
        'left': viewInsets.left / dpr,
        'right': viewInsets.right / dpr,
      },
    };
  }

  Map<String, dynamic> _getScreenInfo() {
    final view = ui.PlatformDispatcher.instance.views.first;
    final dpr = view.devicePixelRatio;
    final size = view.physicalSize;

    final context = AppContext().context;
    final orientation =
        context != null ? MediaQuery.of(context).orientation.name : 'unknown';

    return {
      'width': size.width / dpr,
      'height': size.height / dpr,
      'physicalWidth': size.width,
      'physicalHeight': size.height,
      'devicePixelRatio': dpr,
      'orientation': orientation,
      'textScaleFactor':
          context != null ? MediaQuery.of(context).textScaler.scale(1.0) : 1.0,
    };
  }
}
