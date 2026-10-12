import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('BridgeAuth', () {
    late BridgeAuth auth;

    setUp(() {
      auth = BridgeAuth(sessionTimeout: const Duration(seconds: 5));
    });

    test('createSession returns token', () {
      final token = auth.createSession();
      expect(token, isNotEmpty);
      expect(token.length, greaterThan(20));
    });

    test('validateToken accepts valid token', () {
      final token = auth.createSession();
      expect(auth.validateToken(token), true);
    });

    test('validateToken rejects null token', () {
      auth.createSession();
      expect(auth.validateToken(null), false);
    });

    test('validateToken rejects empty token', () {
      auth.createSession();
      expect(auth.validateToken(''), false);
    });

    test('validateToken rejects wrong token', () {
      auth.createSession();
      expect(auth.validateToken('wrong_token'), false);
    });

    test('validateToken rejects without session', () {
      expect(auth.validateToken('any_token'), false);
    });

    test('revokeSession invalidates token', () {
      final token = auth.createSession();
      auth.revokeSession();
      expect(auth.validateToken(token), false);
    });

    test('session expires after timeout', () async {
      final shortAuth = BridgeAuth(
        sessionTimeout: const Duration(milliseconds: 100),
      );
      final token = shortAuth.createSession();

      expect(shortAuth.validateToken(token), true);

      await Future.delayed(const Duration(milliseconds: 200));

      expect(shortAuth.validateToken(token), false);
    });

    test('createSession generates unique tokens', () {
      final token1 = auth.createSession();
      final token2 = auth.createSession();
      expect(token1, isNot(token2));
    });

    test('stats tracking', () {
      auth.createSession();
      auth.validateToken(auth.currentToken);
      auth.validateToken(auth.currentToken);

      final stats = auth.stats;
      expect(stats['hasSession'], true);
      expect(stats['messageCount'], 2);
    });

    test('signMessage produces consistent output', () {
      final message = {'plugin': 'test', 'method': 'run'};
      final sig1 = BridgeAuth.signMessage(message, 'secret');
      final sig2 = BridgeAuth.signMessage(message, 'secret');
      expect(sig1, sig2);
    });

    test('signMessage different secret = different signature', () {
      final message = {'plugin': 'test', 'method': 'run'};
      final sig1 = BridgeAuth.signMessage(message, 'secret1');
      final sig2 = BridgeAuth.signMessage(message, 'secret2');
      expect(sig1, isNot(sig2));
    });
  });
}
