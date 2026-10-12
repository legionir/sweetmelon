import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

import '../../helpers/mock_plugin.dart';

void main() {
  group('PluginRegistry', () {
    late PluginRegistry registry;

    setUp(() {
      registry = PluginRegistry();
    });

    tearDown(() async {
      await registry.dispose();
    });

    test('register and resolve plugin', () async {
      final plugin = MockPlugin(pluginName: 'test');
      await registry.register(plugin);

      final resolved = registry.resolve('test');

      expect(resolved, isNotNull);
      expect(resolved!.name, 'test');
      expect(resolved.isReady, true);
    });

    test('resolve returns null for unknown plugin', () {
      expect(registry.resolve('nonexistent'), isNull);
    });

    test('isRegistered returns correct value', () async {
      final plugin = MockPlugin(pluginName: 'test');
      await registry.register(plugin);

      expect(registry.isRegistered('test'), true);
      expect(registry.isRegistered('nonexistent'), false);
    });

    test('unregister disposes plugin', () async {
      final plugin = MockPlugin(pluginName: 'test');
      await registry.register(plugin);

      await registry.unregister('test');

      expect(registry.isRegistered('test'), false);
      expect(plugin.disposeCount, 1);
    });

    test('register replaces existing plugin', () async {
      final plugin1 = MockPlugin(pluginName: 'test');
      final plugin2 = MockPlugin(pluginName: 'test');

      await registry.register(plugin1);
      await registry.register(plugin2);

      expect(plugin1.disposeCount, 1);
      expect(registry.resolve('test'), plugin2);
    });

    test('registeredPlugins returns all names', () async {
      await registry.register(MockPlugin(pluginName: 'a'));
      await registry.register(MockPlugin(pluginName: 'b'));
      await registry.register(MockPlugin(pluginName: 'c'));

      expect(registry.registeredPlugins, containsAll(['a', 'b', 'c']));
    });

    test('getPluginInfos returns correct info', () async {
      await registry.register(MockPlugin(
        pluginName: 'test',
        methods: ['m1', 'm2'],
      ));

      final infos = registry.getPluginInfos();

      expect(infos.length, 1);
      expect(infos[0].name, 'test');
      expect(infos[0].supportedMethods, ['m1', 'm2']);
      expect(infos[0].isReady, true);
    });

    test('events stream emits registration events', () async {
      final events = <PluginRegistrationEvent>[];
      registry.events.listen(events.add);

      await registry.register(MockPlugin(pluginName: 'test'));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(events.length, 1);
      expect(events[0].type, RegistrationEventType.registered);
      expect(events[0].pluginName, 'test');
    });

    test('dispose disposes all plugins', () async {
      final p1 = MockPlugin(pluginName: 'a');
      final p2 = MockPlugin(pluginName: 'b');

      await registry.register(p1);
      await registry.register(p2);

      await registry.dispose();

      expect(p1.disposeCount, 1);
      expect(p2.disposeCount, 1);
    });
  });
}
