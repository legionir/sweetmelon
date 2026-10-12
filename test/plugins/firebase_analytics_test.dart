import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/firebase_analytics/lib/firebase_analytics_plugin.dart';

void main() {
  group('FirebaseAnalyticsPlugin', () {
    late FirebaseAnalyticsPlugin plugin;

    setUp(() async {
      plugin = FirebaseAnalyticsPlugin();
      // Note: Firebase.initializeApp() باید قبل از تست‌ها صدا زده بشه
      // در تست واقعی از firebase_core_test_utils استفاده می‌شه
    });

    test('info', () {
      expect(plugin.name, 'firebaseAnalytics');
      expect(plugin.version, '1.0.0');
      expect(plugin.supportedMethods, isNotEmpty);
    });

    test('validation requires event name', () async {
      final r1 = await plugin.validateArgs('logEvent', {});
      expect(r1.isValid, false);

      final r2 = await plugin.validateArgs('logEvent', {'name': 'test_event'});
      expect(r2.isValid, true);
    });

    test('validation requires screen name', () async {
      final r = await plugin.validateArgs('setCurrentScreen', {});
      expect(r.isValid, false);
    });

    test('validation requires search term', () async {
      final r = await plugin.validateArgs('logSearch', {});
      expect(r.isValid, false);
    });

    test('supports all declared methods', () {
      for (final method in plugin.supportedMethods) {
        expect(plugin.supportsMethod(method), true);
      }
    });
  });
}
