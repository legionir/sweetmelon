import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/app_update/lib/app_update_plugin.dart';

void main() {
  group('AppUpdatePlugin', () {
    late AppUpdatePlugin plugin;

    setUp(() async {
      plugin = AppUpdatePlugin();
      await plugin.initialize();
    });

    test('configure sets URLs', () async {
      final r = await plugin.onCall('configure', {
        'updateCheckUrl': 'https://api.example.com/version',
        'playStoreUrl':
            'https://play.google.com/store/apps/details?id=com.example',
      });

      expect(r['configured'], true);
    });

    test('getInfo returns current state', () async {
      final r = await plugin.onCall('getInfo', {});
      expect(r['name'], 'appUpdate');
    });

    test('checkForUpdate without URL returns no update', () async {
      final r = await plugin.onCall('checkForUpdate', {});
      expect(r['checked'], true);
      expect(r['updateAvailable'], false);
    });
  });
}
