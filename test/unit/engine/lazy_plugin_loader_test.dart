import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

import '../../helpers/mock_plugin.dart';

void main() {
  group('LazyPluginLoader', () {
    late PluginRegistry registry;
    late LazyPluginLoader loader;

    setUp(() {
      registry = PluginRegistry();
      loader = LazyPluginLoader(registry: registry);
    });

    tearDown(() async {
      await loader.dispose();
      await registry.dispose();
    });

    test('registers lazy plugin definition', () {
      loader.register(LazyPluginDefinition(
        id: 'test',
        version: '1.0.0',
        factory: () => MockPlugin(pluginName: 'test'),
      ));

      expect(loader.canLoad('test'), true);
      expect(loader.isLoaded('test'), false);
    });

    test('loads plugin on demand', () async {
      loader.register(LazyPluginDefinition(
        id: 'lazy1',
        version: '1.0.0',
        factory: () => MockPlugin(pluginName: 'lazy1'),
      ));

      final plugin = await loader.load('lazy1');

      expect(plugin, isNotNull);
      expect(plugin.name, 'lazy1');
      expect(plugin.isReady, true);
      expect(loader.isLoaded('lazy1'), true);
      expect(registry.isRegistered('lazy1'), true);
    });

    test('returns same instance on repeated load', () async {
      loader.register(LazyPluginDefinition(
        id: 'lazy2',
        version: '1.0.0',
        factory: () => MockPlugin(pluginName: 'lazy2'),
      ));

      final p1 = await loader.load('lazy2');
      final p2 = await loader.load('lazy2');

      expect(identical(p1, p2), true);
    });

    test('unload disposes and removes plugin', () async {
      final plugin = MockPlugin(pluginName: 'lazy3');

      loader.register(LazyPluginDefinition(
        id: 'lazy3',
        version: '1.0.0',
        factory: () => plugin,
      ));

      await loader.load('lazy3');
      expect(loader.isLoaded('lazy3'), true);

      await loader.unload('lazy3');
      expect(loader.isLoaded('lazy3'), false);
      expect(registry.isRegistered('lazy3'), false);
    });

    test('reload creates new instance', () async {
      int createCount = 0;

      loader.register(LazyPluginDefinition(
        id: 'lazy4',
        version: '1.0.0',
        factory: () {
          createCount++;
          return MockPlugin(pluginName: 'lazy4');
        },
      ));

      await loader.load('lazy4');
      expect(createCount, 1);

      await loader.reload('lazy4');
      expect(createCount, 2);
      expect(loader.isLoaded('lazy4'), true);
    });

    test('loads dependencies first', () async {
      final loadOrder = <String>[];

      loader.registerAll([
        LazyPluginDefinition(
          id: 'dep_a',
          version: '1.0.0',
          factory: () {
            loadOrder.add('dep_a');
            return MockPlugin(pluginName: 'dep_a');
          },
        ),
        LazyPluginDefinition(
          id: 'dep_b',
          version: '1.0.0',
          factory: () {
            loadOrder.add('dep_b');
            return MockPlugin(pluginName: 'dep_b');
          },
          dependencies: ['dep_a'],
        ),
      ]);

      await loader.load('dep_b');

      expect(loadOrder, ['dep_a', 'dep_b']);
    });

    test('loadMany loads multiple plugins', () async {
      loader.registerAll([
        LazyPluginDefinition(
          id: 'multi1',
          version: '1.0.0',
          factory: () => MockPlugin(pluginName: 'multi1'),
        ),
        LazyPluginDefinition(
          id: 'multi2',
          version: '1.0.0',
          factory: () => MockPlugin(pluginName: 'multi2'),
        ),
      ]);

      final plugins = await loader.loadMany(['multi1', 'multi2']);

      expect(plugins.length, 2);
      expect(loader.loadedPlugins.length, 2);
    });

    test('stats are tracked', () async {
      loader.register(LazyPluginDefinition(
        id: 'stat1',
        version: '1.0.0',
        factory: () => MockPlugin(pluginName: 'stat1'),
      ));

      expect(loader.stats['total'], 1);
      expect(loader.stats['loaded'], 0);
      expect(loader.stats['unloaded'], 1);

      await loader.load('stat1');

      expect(loader.stats['loaded'], 1);
      expect(loader.stats['unloaded'], 0);
    });

    test('throws on unknown plugin', () {
      expect(
        () => loader.load('nonexistent'),
        throwsStateError,
      );
    });

    test('handles factory error', () async {
      loader.register(LazyPluginDefinition(
        id: 'broken',
        version: '1.0.0',
        factory: () => throw Exception('factory error'),
      ));

      expect(
        () => loader.load('broken'),
        throwsException,
      );

      final status = loader.allStatuses['broken']!;
      expect(status.state, LazyPluginState.failed);
    });
  });
}
