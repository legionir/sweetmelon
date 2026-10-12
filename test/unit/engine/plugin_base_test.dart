import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class TestPlugin extends BasePlugin {
  @override
  String get name => 'tester';

  @override
  String get version => '1.0.0';

  @override
  List<String> get supportedMethods => const ['ping'];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    return {'pong': true, 'method': method};
  }
}

class LifecyclePlugin extends Plugin {
  int initCount = 0;
  int disposeCount = 0;

  @override
  String get name => 'lifecycle';

  @override
  String get version => '2.0.0';

  @override
  List<String> get supportedMethods => const [];

  @override
  Future<void> onInitialize() async {
    initCount++;
  }

  @override
  Future<void> onDispose() async {
    disposeCount++;
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async =>
      null;
}

void main() {
  group('BasePlugin', () {
    test('exposes identity and delegates onCall', () async {
      final plugin = TestPlugin();

      expect(plugin.name, 'tester');
      expect(plugin.supportsMethod('ping'), true);
      expect(plugin.supportsMethod('missing'), false);
      expect(plugin.toString(), 'Plugin(tester@1.0.0)');
      expect(await plugin.onCall('ping', {}), {'pong': true, 'method': 'ping'});
    });

    test('emitEvent forwards to the event emitter when set', () async {
      final plugin = TestPlugin();
      final emitted = <String, dynamic>{};
      plugin.eventEmitter = (event, data) async {
        emitted[event] = data;
      };

      await plugin.emitEvent('tick', {'n': 1});

      expect(emitted, {
        'tick': {'n': 1},
      });
    });

    test('emitEvent silently drops events when no emitter is set', () async {
      final plugin = TestPlugin();

      await expectLater(plugin.emitEvent('lost', null), completes);
    });

    test('safeExecute returns the wrapped result on success', () async {
      final plugin = TestPlugin();

      final result = await plugin.safeExecute(
        'load',
        () async => {'success': true, 'items': 3},
      );

      expect(result, {'success': true, 'items': 3});
    });

    test('safeExecute converts thrown errors into a failure map', () async {
      final plugin = TestPlugin();

      final result = await plugin.safeExecute(
        'load',
        () async => throw StateError('disk full'),
      );

      expect(result['success'], false);
      expect(result['action'], 'load');
      expect(result['error'], contains('disk full'));
    });

    test('hasContext is false without a registered navigator context', () {
      final plugin = TestPlugin();

      expect(plugin.hasContext, false);
      expect(plugin.context, isNull);
      expect(identical(plugin.appContext, AppContext()), true);
    });

    test('requireContext throws PluginException when no context exists', () {
      final plugin = TestPlugin();

      expect(plugin.requireContext, throwsA(isA<PluginException>()));
    });

    test('log helpers do not throw', () {
      final plugin = TestPlugin();

      expect(() {
        plugin.logInfo('info');
        plugin.logWarn('warn');
        plugin.logError('error');
        plugin.logDebug('debug');
      }, returnsNormally);
    });
  });

  group('Plugin lifecycle', () {
    test('initialize runs once and marks plugin ready', () async {
      final plugin = LifecyclePlugin();

      expect(plugin.isReady, false);
      await plugin.initialize();
      await plugin.initialize();

      expect(plugin.isReady, true);
      expect(plugin.initCount, 1);
    });

    test('dispose only runs after initialize and resets readiness', () async {
      final plugin = LifecyclePlugin();

      await plugin.dispose();
      expect(plugin.disposeCount, 0);

      await plugin.initialize();
      await plugin.dispose();

      expect(plugin.isReady, false);
      expect(plugin.disposeCount, 1);
    });

    test('default validateArgs accepts any input', () async {
      final plugin = LifecyclePlugin();

      final result = await plugin.validateArgs('anything', {'x': 1});

      expect(result.isValid, true);
      expect(plugin.description, '');
      expect(plugin.requiredPermissions, isEmpty);
      expect(plugin.cacheable, false);
    });
  });
}
