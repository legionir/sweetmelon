import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/firebase_auth/lib/firebase_auth_plugin.dart';

/// Exercises every [FirebaseAuthPlugin] method in a Firebase-less test
/// environment. [FirebaseAuthPlugin.onInitialize] catches the missing
/// Firebase app, so every call below must degrade gracefully instead of
/// throwing.
void main() {
  group('FirebaseAuthPlugin graceful degradation', () {
    late FirebaseAuthPlugin plugin;

    setUp(() async {
      plugin = FirebaseAuthPlugin();
      await plugin.initialize();
    });

    tearDown(() async {
      await plugin.dispose();
    });

    test('initialize tolerates a missing Firebase app', () {
      expect(plugin.isReady, true);
    });

    test('getInfo reports an uninitialized signed-out state', () async {
      final result = await plugin.onCall('getInfo', {});

      expect(result['name'], 'firebaseAuth');
      expect(result['initialized'], false);
      expect(result['signedIn'], false);
      expect(result['userId'], isNull);
    });

    test('getCurrentUser reports no user', () async {
      final result = await plugin.onCall('getCurrentUser', {});

      expect(result, {'user': null, 'signedIn': false});
    });

    test('isSignedIn reports false', () async {
      final result = await plugin.onCall('isSignedIn', {});

      expect(result, {'signedIn': false});
    });

    test('signInWithEmail returns an empty result without Firebase', () async {
      final result = await plugin.onCall('signInWithEmail', {
        'email': 'user@example.com',
        'password': 'secret123',
      });

      expect(result['success'], true);
      expect(result['user'], isNull);
      expect(result['isNewUser'], false);
    });

    test('signUpWithEmail returns an empty result without Firebase', () async {
      final result = await plugin.onCall('signUpWithEmail', {
        'email': 'new@example.com',
        'password': 'secret123',
        'displayName': 'New User',
      });

      expect(result['success'], true);
      expect(result['user'], isNull);
      expect(result['isNewUser'], true);
    });

    test('signInWithGoogle reports a cancelled flow', () async {
      final result = await plugin.onCall('signInWithGoogle', {});

      expect(result, {'success': false, 'reason': 'cancelled'});
    });

    test('signInAnonymously returns an empty result without Firebase',
        () async {
      final result = await plugin.onCall('signInAnonymously', {});

      expect(result['success'], true);
      expect(result['user'], isNull);
      expect(result['isAnonymous'], true);
    });

    test('signInWithCustomToken returns an empty result', () async {
      final result = await plugin.onCall(
        'signInWithCustomToken',
        {'token': 'token-123'},
      );

      expect(result['success'], true);
      expect(result['user'], isNull);
    });

    test('signOut succeeds as a no-op', () async {
      final result = await plugin.onCall('signOut', {});

      expect(result, {'success': true});
    });

    test('sendPasswordResetEmail succeeds as a no-op', () async {
      final result = await plugin.onCall(
        'sendPasswordResetEmail',
        {'email': 'user@example.com'},
      );

      expect(result, {'success': true, 'email': 'user@example.com'});
    });

    test('updatePassword succeeds as a no-op', () async {
      final result = await plugin.onCall(
        'updatePassword',
        {'newPassword': 'new-secret'},
      );

      expect(result, {'success': true});
    });

    test('updateEmail succeeds as a no-op', () async {
      final result = await plugin.onCall(
        'updateEmail',
        {'newEmail': 'moved@example.com'},
      );

      expect(result, {'success': true, 'pendingVerification': true});
    });

    test('updateProfile succeeds as a no-op', () async {
      final result = await plugin.onCall('updateProfile', {
        'displayName': 'Profile Name',
        'photoURL': 'https://example.com/avatar.png',
      });

      expect(result, {'success': true});
    });

    test('deleteAccount succeeds as a no-op', () async {
      final result = await plugin.onCall('deleteAccount', {});

      expect(result, {'success': true});
    });

    test('reloadUser reports no user', () async {
      final result = await plugin.onCall('reloadUser', {});

      expect(result, {'user': null, 'signedIn': false});
    });

    test('sendEmailVerification succeeds as a no-op', () async {
      final result = await plugin.onCall('sendEmailVerification', {});

      expect(result, {'success': true});
    });

    test('getIdToken reports no token', () async {
      final result = await plugin.onCall('getIdToken', {});

      expect(result['token'], isNull);
    });

    test('unknown methods throw UnsupportedError', () async {
      await expectLater(plugin.onCall('hack', {}), throwsUnsupportedError);
    });
  });
}
