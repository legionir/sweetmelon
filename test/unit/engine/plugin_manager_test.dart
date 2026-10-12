import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

import '../../helpers/mock_plugin.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('PluginManager', () {
    late PluginRegistry registry;
    late PluginManager manager;
    late MockPlugin plugin;

    setUp(() async {
      registry = PluginRegistry();
      plugin = MockPlugin();
      await registry.register(plugin);
      manager = createTestPluginManager(registry: registry);
    });

    tearDown(() async {
      manager.dispose();
      await registry.dispose();
    });

    test('executes plugin method successfully', () async {
      final request = createTestRequest(
        plugin: 'mockPlugin',
        method: 'doSomething',
        args: {'key': 'value'},
      );

      final response = await manager.execute(request);

      expect(response.success, true);
      expect(response.data['done'], true);
      expect(plugin.callCount, 1);
    });

    test('returns error for unknown plugin', () async {
      final request = createTestRequest(
        plugin: 'nonexistent',
        method: 'run',
      );

      final response = await manager.execute(request);

      expect(response.success, false);
      expect(response.error!.code, PluginErrorCode.pluginNotFound);
    });

    test('returns error for unknown method', () async {
      final request = createTestRequest(
        plugin: 'mockPlugin',
        method: 'nonexistentMethod',
      );

      final response = await manager.execute(request);

      expect(response.success, false);
      expect(response.error!.code, PluginErrorCode.methodNotFound);
    });

    test('handles plugin execution error', () async {
      plugin.shouldFail = true;
      plugin.failMessage = 'Test failure';

      final request = createTestRequest();
      final response = await manager.execute(request);

      expect(response.success, false);
      expect(response.error!.code, PluginErrorCode.executionError);
    });

    test('caches results for cacheable plugins', () async {
      final cachePlugin = CacheableMockPlugin();
      await registry.register(cachePlugin);

      final request1 = createTestRequest(
        plugin: 'cacheableMock',
        method: 'getData',
        args: {'key': 'test'},
      );

      final response1 = await manager.execute(request1);
      expect(response1.success, true);
      expect(response1.metadata.fromCache, false);

      final response2 = await manager.execute(request1);
      expect(response2.success, true);
      expect(response2.metadata.fromCache, true);

      expect(cachePlugin.callCount, 1); // cache hit
    });

    test('invalidates cache on mutation', () async {
      final cachePlugin = CacheableMockPlugin();
      await registry.register(cachePlugin);

      // Read
      final getRequest = createTestRequest(
        plugin: 'cacheableMock',
        method: 'getData',
        args: {'key': 'test'},
      );
      await manager.execute(getRequest);

      // Mutation
      final setRequest = createTestRequest(
        plugin: 'cacheableMock',
        method: 'setData',
        args: {'key': 'test', 'value': 'new'},
      );
      await manager.execute(setRequest);

      // Read again — should NOT be cached
      final response = await manager.execute(getRequest);
      expect(response.metadata.fromCache, false);
      expect(cachePlugin.callCount, 3);
    });

    test('batch execution parallel', () async {
      final requests = List.generate(
          5,
          (i) => createTestRequest(
                args: {'index': i},
              ));

      final responses = await manager.executeBatch(
        requests,
        const BatchOptions(parallel: true, stopOnError: false),
      );

      expect(responses.length, 5);
      expect(allSuccessful(responses), true);
    });

    test('batch execution sequential with stopOnError', () async {
      plugin.shouldFail = false;

      int callIndex = 0;
      final failPlugin = MockPlugin(
        pluginName: 'failAt3',
        handlers: {
          'doSomething': (args) {
            callIndex++;
            if (callIndex == 3) throw Exception('fail at 3');
            return {'index': callIndex};
          },
        },
      );

      await registry.register(failPlugin);

      final requests = List.generate(
          5,
          (i) => createTestRequest(
                plugin: 'failAt3',
              ));

      final responses = await manager.executeBatch(
        requests,
        const BatchOptions(parallel: false, stopOnError: true),
      );

      expect(responses.length, 3);
      expect(responses[0].success, true);
      expect(responses[1].success, true);
      expect(responses[2].success, false);
    });

    test('records stats', () async {
      await manager.execute(createTestRequest());
      await manager.execute(createTestRequest());

      final stats = manager.stats;
      expect(stats, isNotEmpty);

      const key = 'mockPlugin.doSomething';
      expect(stats[key]!.totalCalls, 2);
    });

    test('emits traces', () async {
      final traces = <PluginTrace>[];
      manager.traces.listen(traces.add);

      await manager.execute(createTestRequest());

      await Future.delayed(const Duration(milliseconds: 50));

      expect(traces.length, 1);
      expect(traces[0].success, true);
      expect(traces[0].plugin, 'mockPlugin');
    });
  });
}
