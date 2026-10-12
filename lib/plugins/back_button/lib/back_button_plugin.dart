import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef BackButtonEventEmitter = Future<void> Function(
  String event,
  dynamic data,
);

class BackButtonPlugin extends Plugin {
  final BackButtonEventEmitter? eventEmitter;

  bool _interceptEnabled = false;
  bool _exitOnBack = false;

  BackButtonPlugin({this.eventEmitter});

  @override
  String get name => 'backButton';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Android back button and system navigation plugin';

  @override
  List<String> get supportedMethods => [
        'enableIntercept',
        'disableIntercept',
        'getState',
        'exitApp',
        'setExitOnBack',
        'minimizeApp',
      ];

  MethodChannel? _channel;

  @override
  Future<void> onInitialize() async {
    _channel = const MethodChannel('sweetmelon/back_button');

    _channel!.setMethodCallHandler((call) async {
      if (call.method == 'onBackPressed') {
        await _handleBackPress();
      }
      return null;
    });

    // Flutter 3.x+ predictive back gesture support
    SystemChannels.navigation.setMethodCallHandler((call) async {
      if (call.method == 'popRoute') {
        if (_interceptEnabled) {
          await _handleBackPress();
          return true; // consumed
        }
        return false;
      }
      return null;
    });
  }

  @override
  Future<void> onDispose() async {
    _interceptEnabled = false;
    _channel?.setMethodCallHandler(null);
  }

  Future<void> _handleBackPress() async {
    BridgeLogger.info(
        'BackButton', 'Back pressed (intercept: $_interceptEnabled)');

    if (_interceptEnabled && eventEmitter != null) {
      await eventEmitter!(
        'backButton.pressed',
        {
          'intercepted': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } else if (_exitOnBack) {
      SystemNavigator.pop();
    }
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'enableIntercept':
        _interceptEnabled = true;
        return {'interceptEnabled': true};

      case 'disableIntercept':
        _interceptEnabled = false;
        return {'interceptEnabled': false};

      case 'getState':
        return {
          'interceptEnabled': _interceptEnabled,
          'exitOnBack': _exitOnBack,
        };

      case 'exitApp':
        SystemNavigator.pop();
        return {'exiting': true};

      case 'setExitOnBack':
        _exitOnBack = args['enabled'] as bool? ?? false;
        return {'exitOnBack': _exitOnBack};

      case 'minimizeApp':
        // Move app to background
        await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        return {'minimized': true};

      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }
}
