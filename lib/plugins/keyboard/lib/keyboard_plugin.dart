import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef KeyboardEventEmitter = Future<void> Function(
  String event,
  dynamic data,
);

class KeyboardPlugin extends Plugin with WidgetsBindingObserver {
  final KeyboardEventEmitter? eventEmitter;

  bool _watchEnabled = false;
  bool _isVisible = false;
  double _keyboardHeight = 0;

  KeyboardPlugin({this.eventEmitter});

  @override
  String get name => 'keyboard';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Keyboard visibility and height plugin';

  @override
  List<String> get supportedMethods => [
        'getState',
        'startWatch',
        'stopWatch',
        'hide',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<void> onDispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _watchEnabled = false;
  }

  @override
  void didChangeMetrics() {
    _checkKeyboardState();
  }

  void _checkKeyboardState() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;

    final wasVisible = _isVisible;
    _isVisible = bottomInset > 50;
    _keyboardHeight = bottomInset;

    if (_watchEnabled && wasVisible != _isVisible && eventEmitter != null) {
      eventEmitter!(
        'keyboard.change',
        {
          'visible': _isVisible,
          'height': _keyboardHeight,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getState':
        _checkKeyboardState();
        return {
          'visible': _isVisible,
          'height': _keyboardHeight,
        };

      case 'startWatch':
        _watchEnabled = true;
        return {'watching': true};

      case 'stopWatch':
        _watchEnabled = false;
        return {'watching': false};

      case 'hide':
        FocusManager.instance.primaryFocus?.unfocus();
        return {'hidden': true};

      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'watching': _watchEnabled,
          'visible': _isVisible,
          'height': _keyboardHeight,
        };

      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }
}
