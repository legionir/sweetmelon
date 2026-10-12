import 'dart:async';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef SplashEventEmitter = Future<void> Function(String event, dynamic data);

class SplashScreenPlugin extends Plugin {
  final SplashEventEmitter? eventEmitter;

  bool _isVisible = true;
  bool _autoHide = true;
  int _autoHideDelayMs = 0;
  Timer? _autoHideTimer;

  /// Callback برای کنترل splash از UI layer
  static void Function(bool visible)? onVisibilityChanged;

  SplashScreenPlugin({this.eventEmitter});

  @override
  String get name => 'splashScreen';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Splash screen control plugin';

  @override
  List<String> get supportedMethods => [
        'show',
        'hide',
        'setAutoHide',
        'isVisible',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    if (_autoHide && _autoHideDelayMs > 0) {
      _autoHideTimer = Timer(
        Duration(milliseconds: _autoHideDelayMs),
        () => _hideSplash(),
      );
    }
  }

  @override
  Future<void> onDispose() async {
    _autoHideTimer?.cancel();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'show':
        return _showSplash(args);
      case 'hide':
        return _hideSplash();
      case 'setAutoHide':
        return _setAutoHide(args);
      case 'isVisible':
        return {'visible': _isVisible};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'visible': _isVisible,
          'autoHide': _autoHide,
          'autoHideDelayMs': _autoHideDelayMs,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _showSplash(Map<String, dynamic> args) {
    final fadeInDurationMs = (args['fadeInDurationMs'] as num?)?.toInt() ?? 200;

    _isVisible = true;
    onVisibilityChanged?.call(true);

    BridgeLogger.info('SplashScreen', 'Splash shown');

    eventEmitter?.call('splash.shown', {
      'timestamp': DateTime.now().toIso8601String(),
    });

    return {'visible': true, 'fadeInDurationMs': fadeInDurationMs};
  }

  Map<String, dynamic> _hideSplash() {
    _autoHideTimer?.cancel();
    _isVisible = false;
    onVisibilityChanged?.call(false);

    BridgeLogger.info('SplashScreen', 'Splash hidden');

    eventEmitter?.call('splash.hidden', {
      'timestamp': DateTime.now().toIso8601String(),
    });

    return {'visible': false};
  }

  Map<String, dynamic> _setAutoHide(Map<String, dynamic> args) {
    _autoHide = args['enabled'] as bool? ?? true;
    _autoHideDelayMs = (args['delayMs'] as num?)?.toInt() ?? 3000;

    if (_autoHide && _isVisible) {
      _autoHideTimer?.cancel();
      _autoHideTimer = Timer(
        Duration(milliseconds: _autoHideDelayMs),
        () => _hideSplash(),
      );
    }

    return {
      'autoHide': _autoHide,
      'delayMs': _autoHideDelayMs,
    };
  }
}
