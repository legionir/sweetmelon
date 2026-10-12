import 'package:flutter_test/flutter_test.dart';

import 'package:sweetmelon/plugins/alarm/lib/alarm_plugin.dart';
import 'package:sweetmelon/plugins/shake_detection/lib/shake_detection_plugin.dart';
import 'package:sweetmelon/plugins/kiosk_mode/lib/kiosk_mode_plugin.dart';
import 'package:sweetmelon/plugins/root_detection/lib/root_detection_plugin.dart';
import 'package:sweetmelon/plugins/badge/lib/badge_plugin.dart';
import 'package:sweetmelon/plugins/text_zoom/lib/text_zoom_plugin.dart';

import '../helpers/plugin_test_utils.dart';

void main() {
  // ── Alarm ──
  group('AlarmPlugin', () {
    late AlarmPlugin plugin;
    final events = <Map<String, dynamic>>[];

    setUp(() async {
      events.clear();
      plugin = AlarmPlugin(eventEmitter: (e, d) async {
        events.add({'event': e, 'data': d});
      });
      await plugin.initialize();
    });

    tearDown(() async => await plugin.dispose());

    test('info', () async {
      await PluginTestUtils.testPluginInfo(
        plugin,
        expectedName: 'alarm',
        expectedVersion: '1.0.0',
      );
    });

    test('set alarm', () async {
      final result = await plugin.onCall('set', {
        'alarmId': 'test1',
        'delayMs': 100000,
        'title': 'Test',
      });
      expect(result['set'], true);
      expect(result['alarmId'], 'test1');
    });

    test('cancel alarm', () async {
      await plugin.onCall('set', {'alarmId': 'test2', 'delayMs': 100000});
      final result = await plugin.onCall('cancel', {'alarmId': 'test2'});
      expect(result['cancelled'], true);
    });

    test('getAllAlarms', () async {
      await plugin.onCall('set', {'alarmId': 'a1', 'delayMs': 100000});
      await plugin.onCall('set', {'alarmId': 'a2', 'delayMs': 200000});
      final result = await plugin.onCall('getAllAlarms', {});
      expect(result['count'], 2);
    });

    test('cancelAll', () async {
      await plugin.onCall('set', {'alarmId': 'x1', 'delayMs': 100000});
      await plugin.onCall('set', {'alarmId': 'x2', 'delayMs': 200000});
      final result = await plugin.onCall('cancelAll', {});
      expect(result['cancelled'], 2);
    });

    test('fires event after delay', () async {
      await plugin.onCall('set', {
        'alarmId': 'fast',
        'delayMs': 100,
        'title': 'Quick',
      });

      await Future.delayed(const Duration(milliseconds: 200));
      expect(events.any((e) => e['event'] == 'alarm.fired'), true);
    });

    test('validation', () async {
      await PluginTestUtils.testValidation(plugin, 'set', {});
      await PluginTestUtils.testValidation(plugin, 'cancel', {});
    });
  });

  // ── ShakeDetection ──
  group('ShakeDetectionPlugin', () {
    late ShakeDetectionPlugin plugin;

    setUp(() async {
      plugin = ShakeDetectionPlugin();
      await plugin.initialize();
    });

    tearDown(() async => await plugin.dispose());

    test('info', () async {
      await PluginTestUtils.testPluginInfo(
        plugin,
        expectedName: 'shakeDetection',
        expectedVersion: '1.0.0',
      );
    });

    test('configure threshold', () async {
      final result = await plugin.onCall('configure', {
        'threshold': 20.0,
        'cooldownMs': 2000,
      });
      expect(result['threshold'], 20.0);
      expect(result['cooldownMs'], 2000);
    });

    test('resetCount', () async {
      final result = await plugin.onCall('resetCount', {});
      expect(result['reset'], true);
    });
  });

  // ── KioskMode ──
  group('KioskModePlugin', () {
    late KioskModePlugin plugin;

    setUp(() async {
      plugin = KioskModePlugin();
      await plugin.initialize();
    });

    tearDown(() async => await plugin.dispose());

    test('initial state is disabled', () async {
      final result = await plugin.onCall('isEnabled', {});
      expect(result['enabled'], false);
    });
  });

  // ── RootDetection ──
  group('RootDetectionPlugin', () {
    late RootDetectionPlugin plugin;

    setUp(() async {
      plugin = RootDetectionPlugin();
      await plugin.initialize();
    });

    test('info', () async {
      await PluginTestUtils.testPluginInfo(
        plugin,
        expectedName: 'rootDetection',
        expectedVersion: '1.0.0',
      );
    });

    test('isRooted returns map with checks', () async {
      final result = await plugin.onCall('isRooted', {});
      expect(result, containsPair('isRooted', isA<bool>()));
      expect(result, containsPair('riskLevel', isA<String>()));
      expect(result, containsPair('checks', isA<Map>()));
    });

    test('getSecurityInfo includes extra fields', () async {
      final result = await plugin.onCall('getSecurityInfo', {});
      expect(result, containsPair('isEmulator', isA<bool>()));
      expect(result, containsPair('isDebugMode', isA<bool>()));
    });
  });

  // ── Badge ──
  group('BadgePlugin', () {
    late BadgePlugin plugin;

    setUp(() async {
      plugin = BadgePlugin();
      await plugin.initialize();
    });

    test('initial count is 0', () async {
      final result = await plugin.onCall('get', {});
      expect(result['count'], 0);
    });

    test('validation', () async {
      await PluginTestUtils.testValidation(plugin, 'set', {});
      await PluginTestUtils.testValidArgs(plugin, 'set', {'count': 5});
    });
  });

  // ── TextZoom ──
  group('TextZoomPlugin', () {
    late TextZoomPlugin plugin;

    setUp(() async {
      plugin = TextZoomPlugin();
      await plugin.initialize();
    });

    test('default zoom is 100', () async {
      final result = await plugin.onCall('get', {});
      expect(result['zoom'], 100);
    });

    test('set zoom', () async {
      final result = await plugin.onCall('set', {'zoom': 150});
      expect(result['zoom'], 150);
    });

    test('increase', () async {
      await plugin.onCall('set', {'zoom': 100});
      final result = await plugin.onCall('increase', {'step': 20});
      expect(result['zoom'], 120);
    });

    test('decrease', () async {
      await plugin.onCall('set', {'zoom': 100});
      final result = await plugin.onCall('decrease', {'step': 30});
      expect(result['zoom'], 70);
    });

    test('clamp to min/max', () async {
      final r1 = await plugin.onCall('set', {'zoom': 10});
      expect(r1['zoom'], 50); // min

      final r2 = await plugin.onCall('set', {'zoom': 500});
      expect(r2['zoom'], 300); // max
    });

    test('reset', () async {
      await plugin.onCall('set', {'zoom': 200});
      final result = await plugin.onCall('reset', {});
      expect(result['zoom'], 100);
    });

    test('validation', () async {
      await PluginTestUtils.testValidation(plugin, 'set', {});
    });
  });
}
