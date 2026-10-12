import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/cookie_manager/lib/cookie_manager_plugin.dart';

void main() {
  group('CookieManagerPlugin', () {
    late CookieManagerPlugin plugin;

    setUp(() async {
      plugin = CookieManagerPlugin();
      await plugin.initialize();
    });

    test('validates setCookie requires domain, name, value', () async {
      final r1 = await plugin.validateArgs('setCookie', {});
      expect(r1.isValid, false);

      final r2 = await plugin.validateArgs('setCookie', {
        'domain': 'example.com',
        'name': 'token',
        'value': 'abc123',
      });
      expect(r2.isValid, true);
    });

    test('supports all declared methods', () {
      expect(plugin.supportsMethod('setCookie'), true);
      expect(plugin.supportsMethod('clearCookies'), true);
      expect(plugin.supportsMethod('clearSession'), true);
    });
  });
}
