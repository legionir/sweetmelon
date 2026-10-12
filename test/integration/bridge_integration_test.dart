import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:sweetmelon/plugins/storage/lib/storage_plugin.dart';
import 'package:sweetmelon/plugins/clipboard/lib/clipboard_plugin.dart';
import 'package:sweetmelon/plugins/encryption/lib/encryption_plugin.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('Bridge Integration', () {
    late PluginRegistry registry;
    late PluginManager manager;
    late MessageBridge bridge;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      registry = PluginRegistry();
      manager = createTestPluginManager(registry: registry);

      bridge = MessageBridge();
      bridge.setMessageHandler(manager.execute);
      bridge.setBatchHandler(manager.executeBatch);

      await registry.register(StoragePlugin());
      await registry.register(ClipboardPlugin());
      await registry.register(EncryptionPlugin());
    });

    tearDown(() async {
      bridge.dispose();
      manager.dispose();
      await registry.dispose();
    });

    test('full message flow: storage set then get', () async {
      // Set
      await bridge.handleIncomingMessage({
        'requestId': 'set_1',
        'plugin': 'storage',
        'method': 'set',
        'args': {
          'key': 'integration_test',
          'value': {'data': 42}
        },
      });

      // Get
      PluginResponse? response;
      bridge.setMessageHandler((request) async {
        response = await manager.execute(request);
        return response!;
      });

      await bridge.handleIncomingMessage({
        'requestId': 'get_1',
        'plugin': 'storage',
        'method': 'get',
        'args': {'key': 'integration_test'},
      });

      expect(response, isNotNull);
      expect(response!.success, true);
    });

    test('encryption roundtrip through bridge', () async {
      // Generate key
      final keyResponse = await manager.execute(
        createTestRequest(
          plugin: 'encryption',
          method: 'generateAesKey',
          args: {'bits': 256},
        ),
      );

      expect(keyResponse.success, true);
      final key = keyResponse.data['key'] as String;
      final iv = keyResponse.data['iv'] as String;

      // Encrypt
      final encResponse = await manager.execute(
        createTestRequest(
          plugin: 'encryption',
          method: 'aesEncrypt',
          args: {'data': 'secret message', 'key': key, 'iv': iv},
        ),
      );

      expect(encResponse.success, true);
      final encrypted = encResponse.data['encrypted'] as String;

      // Decrypt
      final decResponse = await manager.execute(
        createTestRequest(
          plugin: 'encryption',
          method: 'aesDecrypt',
          args: {'data': encrypted, 'key': key, 'iv': iv},
        ),
      );

      expect(decResponse.success, true);
      expect(decResponse.data['decrypted'], 'secret message');
    });

    test('batch request through bridge', () async {
      final responses = await manager.executeBatch([
        createTestRequest(
          plugin: 'storage',
          method: 'set',
          args: {'key': 'batch_1', 'value': 'v1'},
        ),
        createTestRequest(
          plugin: 'storage',
          method: 'set',
          args: {'key': 'batch_2', 'value': 'v2'},
        ),
        createTestRequest(
          plugin: 'storage',
          method: 'keys',
        ),
      ], const BatchOptions(parallel: false, stopOnError: false));

      expect(responses.length, 3);
      expect(allSuccessful(responses), true);
    });

    test('error for invalid plugin does not crash', () async {
      final response = await manager.execute(
        createTestRequest(
          plugin: 'nonexistent',
          method: 'anything',
        ),
      );

      expect(response.success, false);
      expect(response.error!.code, PluginErrorCode.pluginNotFound);
    });

    test('error for invalid method does not crash', () async {
      final response = await manager.execute(
        createTestRequest(
          plugin: 'storage',
          method: 'nonexistent',
        ),
      );

      expect(response.success, false);
      expect(response.error!.code, PluginErrorCode.methodNotFound);
    });
  });
}
