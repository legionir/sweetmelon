import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sweetmelon/plugins/clipboard/lib/clipboard_plugin.dart';
import 'package:sweetmelon/plugins/encryption/lib/encryption_plugin.dart';
import 'package:sweetmelon/plugins/haptic/lib/haptic_plugin.dart';
import 'package:sweetmelon/plugins/status_bar/lib/status_bar_plugin.dart';
import 'package:sweetmelon/plugins/storage/lib/storage_plugin.dart';

import '../helpers/plugin_test_utils.dart';

void main() {
  group('All Plugins Basic Tests', () {
    // ── Clipboard ──
    group('ClipboardPlugin', () {
      late ClipboardPlugin plugin;

      setUp(() async {
        plugin = ClipboardPlugin();
        await plugin.initialize();
      });

      tearDown(() async => await plugin.dispose());

      test('info', () async {
        await PluginTestUtils.testPluginInfo(
          plugin,
          expectedName: 'clipboard',
          expectedVersion: '1.0.0',
        );
      });

      test('getInfo', () async {
        await PluginTestUtils.testGetInfo(plugin);
      });

      test('unsupported method', () async {
        await PluginTestUtils.testUnsupportedMethod(plugin);
      });

      test('writeText validation', () async {
        await PluginTestUtils.testValidation(plugin, 'writeText', {});
        await PluginTestUtils.testValidArgs(
          plugin,
          'writeText',
          {'text': 'hello'},
        );
      });

      test('double initialize', () async {
        await PluginTestUtils.testDoubleInitialize(plugin);
      });
    });

    // ── Encryption ──
    group('EncryptionPlugin', () {
      late EncryptionPlugin plugin;

      setUp(() async {
        plugin = EncryptionPlugin();
        await plugin.initialize();
      });

      tearDown(() async => await plugin.dispose());

      test('info', () async {
        await PluginTestUtils.testPluginInfo(
          plugin,
          expectedName: 'encryption',
          expectedVersion: '1.0.0',
        );
      });

      test('generateAesKey', () async {
        final result = await plugin.onCall('generateAesKey', {'bits': 256});
        expect(result['key'], isNotEmpty);
        expect(result['iv'], isNotEmpty);
      });

      test('hashSha256', () async {
        final r1 = await plugin.onCall('hashSha256', {'data': 'test'});
        final r2 = await plugin.onCall('hashSha256', {'data': 'test'});
        expect(r1['hash'], r2['hash']);
        expect(r1['hash'], isNotEmpty);
      });

      test('aes roundtrip', () async {
        final key = await plugin.onCall('generateAesKey', {'bits': 256});
        final enc = await plugin.onCall('aesEncrypt', {
          'data': 'secret',
          'key': key['key'],
          'iv': key['iv'],
        });
        final dec = await plugin.onCall('aesDecrypt', {
          'data': enc['encrypted'],
          'key': key['key'],
          'iv': key['iv'],
        });
        expect(dec['decrypted'], 'secret');
      });

      test('base64 roundtrip', () async {
        final enc = await plugin.onCall('base64Encode', {'data': 'Hello!'});
        final dec =
            await plugin.onCall('base64Decode', {'data': enc['encoded']});
        expect(dec['decoded'], 'Hello!');
      });

      test('hmacSha256', () async {
        final result = await plugin.onCall('hmacSha256', {
          'data': 'message',
          'key': 'secret',
        });
        expect(result['hmac'], isNotEmpty);
      });

      test('validation rejects missing data', () async {
        await PluginTestUtils.testValidation(plugin, 'hashSha256', {});
      });
    });

    // ── Storage ──
    group('StoragePlugin', () {
      late StoragePlugin plugin;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        plugin = StoragePlugin();
        await plugin.initialize();
      });

      tearDown(() async => await plugin.dispose());

      test('info', () async {
        await PluginTestUtils.testPluginInfo(
          plugin,
          expectedName: 'storage',
          expectedVersion: '1.0.0',
        );
      });

      test('set and get', () async {
        await plugin.onCall('set', {'key': 'k1', 'value': 'v1'});
        final result = await plugin.onCall('get', {'key': 'k1'});
        expect(result, 'v1');
      });

      test('get missing returns null', () async {
        final result = await plugin.onCall('get', {'key': 'missing'});
        expect(result, isNull);
      });

      test('has', () async {
        await plugin.onCall('set', {'key': 'exists', 'value': true});
        final r1 = await plugin.onCall('has', {'key': 'exists'});
        expect(r1['exists'], true);
        final r2 = await plugin.onCall('has', {'key': 'nope'});
        expect(r2['exists'], false);
      });

      test('remove', () async {
        await plugin.onCall('set', {'key': 'temp', 'value': 'data'});
        await plugin.onCall('remove', {'key': 'temp'});
        final result = await plugin.onCall('get', {'key': 'temp'});
        expect(result, isNull);
      });

      test('keys', () async {
        await plugin.onCall('set', {'key': 'a', 'value': 1});
        await plugin.onCall('set', {'key': 'b', 'value': 2});
        final result = await plugin.onCall('keys', {});
        expect(result['keys'], containsAll(['a', 'b']));
      });

      test('clear', () async {
        await plugin.onCall('set', {'key': 'x', 'value': 1});
        final count = await plugin.onCall('clear', {});
        expect(count, greaterThanOrEqualTo(1));
      });

      test('complex value', () async {
        final data = {
          'name': 'Ali',
          'scores': [1, 2, 3]
        };
        await plugin.onCall('set', {'key': 'complex', 'value': data});
        final result = await plugin.onCall('get', {'key': 'complex'});
        expect(result['name'], 'Ali');
        expect(result['scores'], [1, 2, 3]);
      });

      test('validation', () async {
        await PluginTestUtils.testValidation(plugin, 'get', {});
        await PluginTestUtils.testValidation(plugin, 'get', {'key': ''});
        await PluginTestUtils.testValidation(plugin, 'set', {'key': 'k'});
      });
    });

    // ── Haptic ──
    group('HapticPlugin', () {
      late HapticPlugin plugin;

      setUp(() async {
        plugin = HapticPlugin();
        await plugin.initialize();
      });

      test('info', () async {
        await PluginTestUtils.testPluginInfo(
          plugin,
          expectedName: 'haptic',
          expectedVersion: '1.0.0',
        );
      });

      test('supports all declared methods', () {
        for (final method in plugin.supportedMethods) {
          expect(plugin.supportsMethod(method), true);
        }
      });
    });

    // ── StatusBar ──
    group('StatusBarPlugin', () {
      late StatusBarPlugin plugin;

      setUp(() async {
        plugin = StatusBarPlugin();
        await plugin.initialize();
      });

      test('info', () async {
        await PluginTestUtils.testPluginInfo(
          plugin,
          expectedName: 'statusBar',
          expectedVersion: '1.0.0',
        );
      });

      test('setStyle returns applied', () async {
        final result = await plugin.onCall('setStyle', {'style': 'dark'});
        expect(result['applied'], true);
      });
    });
  });
}
