import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/firebase_auth/lib/firebase_auth_plugin.dart';

void main() {
  group('FirebaseAuthPlugin', () {
    late FirebaseAuthPlugin plugin;

    setUp(() async {
      plugin = FirebaseAuthPlugin();
    });

    test('info', () {
      expect(plugin.name, 'firebaseAuth');
      expect(plugin.version, '1.0.0');
    });

    test('validation requires email and password for signIn', () async {
      final r1 = await plugin.validateArgs('signInWithEmail', {});
      expect(r1.isValid, false);

      final r2 = await plugin.validateArgs('signInWithEmail', {
        'email': 'test@test.com',
      });
      expect(r2.isValid, false);

      final r3 = await plugin.validateArgs('signInWithEmail', {
        'email': 'test@test.com',
        'password': 'pass123',
      });
      expect(r3.isValid, true);
    });

    test('validation requires email for signUp', () async {
      final r = await plugin.validateArgs('signUpWithEmail', {
        'email': 'test@test.com',
        'password': 'pass123',
      });
      expect(r.isValid, true);
    });

    test('validation requires email for password reset', () async {
      final r1 = await plugin.validateArgs('sendPasswordResetEmail', {});
      expect(r1.isValid, false);

      final r2 = await plugin.validateArgs('sendPasswordResetEmail', {
        'email': 'test@test.com',
      });
      expect(r2.isValid, true);
    });

    test('all methods are declared', () {
      final expectedMethods = [
        'getCurrentUser',
        'signInWithEmail',
        'signUpWithEmail',
        'signInWithGoogle',
        'signOut',
        'isSignedIn'
      ];
      for (final method in expectedMethods) {
        expect(plugin.supportsMethod(method), true, reason: 'Missing: $method');
      }
    });
  });
}
