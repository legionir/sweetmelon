import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/firebase_remote_config/lib/firebase_remote_config_plugin.dart';

void main() {
  group('FirebaseRemoteConfigPlugin', () {
    late FirebaseRemoteConfigPlugin plugin;

    setUp(() async {
      plugin = FirebaseRemoteConfigPlugin();
    });

    test('info', () {
      expect(plugin.name, 'firebaseRemoteConfig');
      expect(plugin.version, '1.0.0');
    });

    test('validation requires key for getters', () async {
      final methods = [
        'getString',
        'getInt',
        'getDouble',
        'getBool',
        'getJson'
      ];
      for (final method in methods) {
        final r = await plugin.validateArgs(method, {});
        expect(r.isValid, false, reason: '$method should require key');

        final r2 = await plugin.validateArgs(method, {'key': 'my_key'});
        expect(r2.isValid, true, reason: '$method with key should be valid');
      }
    });

    test('validation requires map for setDefaults', () async {
      final r =
          await plugin.validateArgs('setDefaults', {'defaults': 'invalid'});
      expect(r.isValid, false);

      final r2 = await plugin.validateArgs('setDefaults', {
        'defaults': {'key1': 'value1'}
      });
      expect(r2.isValid, true);
    });

    test('supports all declared methods', () {
      for (final method in plugin.supportedMethods) {
        expect(plugin.supportsMethod(method), true);
      }
    });
  });
}
