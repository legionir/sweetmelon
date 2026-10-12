import 'package:flutter/widgets.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef LifecycleEventEmitter = Future<void> Function(
  String event,
  dynamic data,
);

class AppLifecyclePlugin extends Plugin with WidgetsBindingObserver {
  final LifecycleEventEmitter? eventEmitter;

  AppLifecycleState? _currentState;
  bool _eventsEnabled = true;

  AppLifecyclePlugin({
    this.eventEmitter,
  });

  @override
  String get name => 'appLifecycle';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'App lifecycle state bridge';

  @override
  List<String> get supportedMethods => [
        'getState',
        'enableEvents',
        'disableEvents',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    WidgetsBinding.instance.addObserver(this);
    _currentState = WidgetsBinding.instance.lifecycleState;
  }

  @override
  Future<void> onDispose() async {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = _currentState;
    _currentState = state;

    BridgeLogger.info(
      'AppLifecycle',
      'State changed: ${previous?.name ?? "unknown"} -> ${state.name}',
    );

    if (_eventsEnabled && eventEmitter != null) {
      eventEmitter!(
        'app.lifecycle.change',
        {
          'state': state.name,
          'previousState': previous?.name,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getState':
        return {
          'state': (_currentState ?? AppLifecycleState.resumed).name,
        };

      case 'enableEvents':
        _eventsEnabled = true;
        return {'enabled': true};

      case 'disableEvents':
        _eventsEnabled = false;
        return {'enabled': false};

      case 'getInfo':
        return {
          'state': (_currentState ?? AppLifecycleState.resumed).name,
          'eventsEnabled': _eventsEnabled,
          'supportedStates':
              AppLifecycleState.values.map((e) => e.name).toList(),
        };

      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }
}
