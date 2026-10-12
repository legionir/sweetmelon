import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sweetmelon/plugins/cache_control/lib/cache_control_plugin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // path_provider has no platform implementation under `flutter test`, so
  // route its method channel to controlled local directories instead.
  final fakeCacheDir = Directory.systemTemp.createTempSync('cache_ctrl_cache');
  final fakeTempDir = Directory.systemTemp.createTempSync('cache_ctrl_temp');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getTemporaryDirectory') {
          return fakeTempDir.path;
        }
        return fakeCacheDir.path;
      },
    );
  });

  group('CacheControlPlugin', () {
    late CacheControlPlugin plugin;

    setUp(() async {
      plugin = CacheControlPlugin();
      await plugin.initialize();
    });

    test('getInfo returns plugin info', () async {
      final r = await plugin.onCall('getInfo', {});
      expect(r['name'], 'cacheControl');
    });

    test('supports all declared methods', () {
      expect(plugin.supportsMethod('clearWebViewCache'), true);
      expect(plugin.supportsMethod('clearAppCache'), true);
      expect(plugin.supportsMethod('getCacheSize'), true);
      expect(plugin.supportsMethod('clearAll'), true);
    });

    test('getCacheSize aggregates cache and temp directories', () async {
      final result = await plugin.onCall('getCacheSize', {});

      for (final section in const ['cache', 'temp', 'total']) {
        expect(result[section], isA<Map<String, dynamic>>());
        expect(result[section]['bytes'], isA<int>());
        expect(result[section]['files'], isA<int>());
        expect(result[section]['formatted'], isA<String>());
        expect(result[section]['bytes'], greaterThanOrEqualTo(0));
      }
      expect(
        result['total']['bytes'],
        result['cache']['bytes'] + result['temp']['bytes'],
      );
      expect(
        result['total']['files'],
        result['cache']['files'] + result['temp']['files'],
      );
    });

    test('clearAppCache deletes files from the app cache directory', () async {
      final cacheDir = await getApplicationCacheDirectory();
      await cacheDir.create(recursive: true);
      final probe = File('${cacheDir.path}/sweetmelon_cache_probe.txt');
      await probe.writeAsString('x' * 2048);

      final result = await plugin.onCall('clearAppCache', {});

      expect(result['cleared'], true);
      expect(result['type'], 'appCache');
      expect(result['filesDeleted'], greaterThanOrEqualTo(1));
      expect(result['bytesFreed'], greaterThanOrEqualTo(2048));
      expect(result['bytesFreedFormatted'], isA<String>());
      expect(await probe.exists(), false);
    });

    test('clearWebViewCache reports failure without a WebView platform',
        () async {
      final result = await plugin.onCall('clearWebViewCache', {});

      expect(result['cleared'], false);
      expect(result['error'], isNotNull);
    });

    test('unknown methods throw UnsupportedError', () async {
      await expectLater(plugin.onCall('defrag', {}), throwsUnsupportedError);
    });
  });
}
