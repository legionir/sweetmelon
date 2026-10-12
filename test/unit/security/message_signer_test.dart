import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('MessageSigner', () {
    test('none level always validates', () {
      final signer = MessageSigner(level: SecurityLevel.none);

      final result = signer.validate(
        {'plugin': 'test'},
        'wrong_token',
        null,
        'secret',
        'expected_token',
      );

      expect(result.valid, true);
    });

    test('tokenOnly validates token', () {
      final signer = MessageSigner(level: SecurityLevel.tokenOnly);

      final valid = signer.validate(
        {'plugin': 'test'},
        'correct_token',
        null,
        'secret',
        'correct_token',
      );
      expect(valid.valid, true);

      final invalid = signer.validate(
        {'plugin': 'test'},
        'wrong_token',
        null,
        'secret',
        'correct_token',
      );
      expect(invalid.valid, false);
      expect(invalid.reason, 'invalid_token');
    });

    test('signed validates signature', () {
      final signer = MessageSigner(level: SecurityLevel.signed);
      final message = {'plugin': 'test', 'method': 'run'};
      final signature = signer.signResponse(message, 'secret');

      final result = signer.validate(
        message,
        'token',
        signature,
        'secret',
        'token',
      );

      expect(result.valid, true);
    });

    test('signed rejects invalid signature', () {
      final signer = MessageSigner(level: SecurityLevel.signed);
      final message = {'plugin': 'test', 'method': 'run'};

      final result = signer.validate(
        message,
        'token',
        'invalid_signature',
        'secret',
        'token',
      );

      expect(result.valid, false);
      expect(result.reason, 'invalid_signature');
    });

    test('signed rejects missing signature', () {
      final signer = MessageSigner(level: SecurityLevel.signed);

      final result = signer.validate(
        {'plugin': 'test'},
        'token',
        null,
        'secret',
        'token',
      );

      expect(result.valid, false);
      expect(result.reason, 'missing_signature');
    });

    test('strict validates timestamp', () {
      final signer = MessageSigner(
        level: SecurityLevel.strict,
        maxMessageAge: const Duration(seconds: 5),
      );

      final message = {
        'plugin': 'test',
        '_ts': DateTime.now().millisecondsSinceEpoch,
        '_nonce': 'unique_nonce_1',
      };

      final signature = signer.signResponse(message, 'secret');

      final result = signer.validate(
        message,
        'token',
        signature,
        'secret',
        'token',
      );

      expect(result.valid, true);
    });

    test('strict rejects expired message', () {
      final signer = MessageSigner(
        level: SecurityLevel.strict,
        maxMessageAge: const Duration(seconds: 1),
      );

      final message = {
        'plugin': 'test',
        '_ts': DateTime.now()
            .subtract(const Duration(seconds: 10))
            .millisecondsSinceEpoch,
        '_nonce': 'nonce_2',
      };

      final signature = signer.signResponse(message, 'secret');

      final result = signer.validate(
        message,
        'token',
        signature,
        'secret',
        'token',
      );

      expect(result.valid, false);
      expect(result.reason, 'message_expired');
    });

    test('strict detects replay', () {
      final signer = MessageSigner(level: SecurityLevel.strict);

      final message = {
        'plugin': 'test',
        '_ts': DateTime.now().millisecondsSinceEpoch,
        '_nonce': 'same_nonce',
      };

      final signature = signer.signResponse(message, 'secret');

      // اول بار OK
      signer.validate(message, 'token', signature, 'secret', 'token');

      // دوم بار replay
      final result = signer.validate(
        message,
        'token',
        signature,
        'secret',
        'token',
      );

      expect(result.valid, false);
      expect(result.reason, 'replay_detected');
    });
  });
}
