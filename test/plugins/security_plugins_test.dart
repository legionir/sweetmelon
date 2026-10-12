import 'package:flutter_test/flutter_test.dart';

import 'package:sweetmelon/plugins/app_integrity/lib/app_integrity_plugin.dart';
import 'package:sweetmelon/plugins/wifi_manager/lib/wifi_manager_plugin.dart';
import 'package:sweetmelon/plugins/email_composer/lib/email_composer_plugin.dart';
import 'package:sweetmelon/plugins/intent_launcher/lib/intent_launcher_plugin.dart';

import '../helpers/plugin_test_utils.dart';

void main() {
  // ── AppIntegrity ──
  group('AppIntegrityPlugin', () {
    late AppIntegrityPlugin plugin;

    setUp(() async {
      plugin = AppIntegrityPlugin();
      await plugin.initialize();
    });

    test('info', () async {
      await PluginTestUtils.testPluginInfo(
        plugin,
        expectedName: 'appIntegrity',
        expectedVersion: '1.0.0',
      );
    });

    test('getInfo returns playIntegrityReady', () async {
      final result = await plugin.onCall('getInfo', {});
      expect(result, containsPair('playIntegrityReady', false));
    });
  });

  // ── WifiManager ──
  group('WifiManagerPlugin', () {
    late WifiManagerPlugin plugin;

    setUp(() async {
      plugin = WifiManagerPlugin();
      await plugin.initialize();
    });

    test('info', () async {
      await PluginTestUtils.testPluginInfo(
        plugin,
        expectedName: 'wifiManager',
        expectedVersion: '1.0.0',
      );
    });

    test('getIpAddress returns map', () async {
      final result = await plugin.onCall('getIpAddress', {});
      expect(result, containsPair('ips', isA<List>()));
    });
  });

  // ── EmailComposer ──
  group('EmailComposerPlugin', () {
    late EmailComposerPlugin plugin;

    setUp(() async {
      plugin = EmailComposerPlugin();
      await plugin.initialize();
    });

    test('info', () async {
      await PluginTestUtils.testPluginInfo(
        plugin,
        expectedName: 'emailComposer',
        expectedVersion: '1.0.0',
      );
    });

    test('validation requires to', () async {
      await PluginTestUtils.testValidation(plugin, 'compose', {});
      await PluginTestUtils.testValidArgs(
        plugin,
        'compose',
        {'to': 'test@test.com'},
      );
    });
  });

  // ── IntentLauncher ──
  group('IntentLauncherPlugin', () {
    late IntentLauncherPlugin plugin;

    setUp(() async {
      plugin = IntentLauncherPlugin();
      await plugin.initialize();
    });

    test('info', () async {
      await PluginTestUtils.testPluginInfo(
        plugin,
        expectedName: 'intentLauncher',
        expectedVersion: '1.0.0',
      );
    });

    test('getInfo returns known intents', () async {
      final result = await plugin.onCall('getInfo', {});
      expect(result['knownIntents'], isNotEmpty);
      expect(result['knownIntents'], contains('wifi'));
      expect(result['knownIntents'], contains('bluetooth'));
    });

    test('validation', () async {
      await PluginTestUtils.testValidation(plugin, 'launch', {});
      await PluginTestUtils.testValidation(plugin, 'isAppInstalled', {});
    });
  });
}
