import 'dart:async';

import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

/// پلاگین ساده برای تست
class MockPlugin extends Plugin {
  final String pluginName;
  final String pluginVersion;
  final List<String> methods;
  final Map<String, dynamic Function(Map<String, dynamic>)> handlers;
  final List<String> permissions;

  int callCount = 0;
  int initCount = 0;
  int disposeCount = 0;
  final List<String> callLog = [];
  bool shouldFail = false;
  String failMessage = 'Mock failure';
  Duration? simulatedDelay;

  MockPlugin({
    this.pluginName = 'mockPlugin',
    this.pluginVersion = '1.0.0',
    this.methods = const ['doSomething', 'getData', 'setData', 'getInfo'],
    this.handlers = const {},
    this.permissions = const [],
  });

  @override
  String get name => pluginName;

  @override
  String get version => pluginVersion;

  @override
  List<String> get supportedMethods => methods;

  @override
  List<String> get requiredPermissions => permissions;

  @override
  Future<void> onInitialize() async {
    initCount++;
  }

  @override
  Future<void> onDispose() async {
    disposeCount++;
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    callCount++;
    callLog.add('$method:${args.toString()}');

    if (simulatedDelay != null) {
      await Future.delayed(simulatedDelay!);
    }

    if (shouldFail) {
      throw Exception(failMessage);
    }

    if (handlers.containsKey(method)) {
      return handlers[method]!(args);
    }

    switch (method) {
      case 'doSomething':
        return {'done': true, 'args': args};
      case 'getData':
        return {'key': args['key'], 'value': 'mock_value'};
      case 'setData':
        return {'saved': true};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'callCount': callCount,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  void reset() {
    callCount = 0;
    initCount = 0;
    disposeCount = 0;
    callLog.clear();
    shouldFail = false;
    simulatedDelay = null;
  }
}

/// پلاگین cacheable
class CacheableMockPlugin extends MockPlugin {
  CacheableMockPlugin({
    super.pluginName = 'cacheableMock',
  });

  @override
  bool get cacheable => true;

  @override
  Duration get defaultCacheTtl => const Duration(seconds: 10);
}

/// پلاگین که initialize خیلی طول می‌کشه
class SlowInitPlugin extends MockPlugin {
  final Duration initDuration;

  SlowInitPlugin({
    super.pluginName = 'slowInit',
    this.initDuration = const Duration(milliseconds: 500),
  });

  @override
  Future<void> onInitialize() async {
    await Future.delayed(initDuration);
    await super.onInitialize();
  }
}

/// پلاگین که initialize خطا می‌ده
class FailingInitPlugin extends MockPlugin {
  FailingInitPlugin({super.pluginName = 'failingInit'});

  @override
  Future<void> onInitialize() async {
    throw Exception('Init failed intentionally');
  }
}
