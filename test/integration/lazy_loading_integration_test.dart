import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

import '../helpers/mock_plugin.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Lazy Loading Integration', () {
    late PluginRegistry registry;
    late LazyPluginLoader loader;
    late PluginManager manager;

    setUp(() {
      registry = PluginRegistry();
      loader = LazyPluginLoader(registry: registry);
      manager = createTestPluginManager(
        registry: registry,
        lazyLoader: loader,
      );
    });

    tearDown(() async {
      manager.dispose();
      await loader.dispose();
      await registry.dispose();
    });

    test('auto-loads lazy plugin on first call', () async {
      loader.register(LazyPluginDefinition(
        id: 'lazyPlugin',
        version: '1.0.0',
        factory: () => MockPlugin(pluginName: 'lazyPlugin'),
      ));

      expect(loader.isLoaded('lazyPlugin'), false);
      expect(registry.isRegistered('lazyPlugin'), false);

      final response = await manager.execute(
        createTestRequest(
          plugin: 'lazyPlugin',
          method: 'doSomething',
        ),
      );

      expect(response.success, true);
      expect(loader.isLoaded('lazyPlugin'), true);
      expect(registry.isRegistered('lazyPlugin'), true);
    });

    test('second call uses already-loaded plugin', () async {
      int createCount = 0;

      loader.register(LazyPluginDefinition(
        id: 'countPlugin',
        version: '1.0.0',
        factory: () {
          createCount++;
          return MockPlugin(pluginName: 'countPlugin');
        },
      ));

      await manager.execute(createTestRequest(plugin: 'countPlugin'));
      await manager.execute(createTestRequest(plugin: 'countPlugin'));

      expect(createCount, 1);
    });

    test('eager and lazy plugins work together', () async {
      // Eager
      final eager = MockPlugin(pluginName: 'eagerPlugin');
      await registry.register(eager);

      // Lazy
      loader.register(LazyPluginDefinition(
        id: 'lazyPlugin',
        version: '1.0.0',
        factory: () => MockPlugin(pluginName: 'lazyPlugin'),
      ));

      // Both should work
      final r1 = await manager.execute(
        createTestRequest(plugin: 'eagerPlugin'),
      );
      final r2 = await manager.execute(
        createTestRequest(plugin: 'lazyPlugin'),
      );

      expect(r1.success, true);
      expect(r2.success, true);
    });

    test('returns plugin not found for unregistered plugin', () async {
      final response = await manager.execute(
        createTestRequest(plugin: 'totallyUnknown'),
      );

      expect(response.success, false);
      expect(response.error!.code, PluginErrorCode.pluginNotFound);
    });

    test('handles lazy load failure gracefully', () async {
      loader.register(LazyPluginDefinition(
        id: 'brokenPlugin',
        version: '1.0.0',
        factory: () => throw Exception('cannot create'),
      ));

      final response = await manager.execute(
        createTestRequest(plugin: 'brokenPlugin'),
      );

      expect(response.success, false);
      expect(response.error!.message, contains('failed to load'));
    });
  });
}
