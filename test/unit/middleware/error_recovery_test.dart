import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('ErrorRecovery.retry', () {
    test('succeeds on first attempt', () async {
      final result = await ErrorRecovery.retry<int>(
        action: () async => 42,
        label: 'test',
      );

      expect(result.success, true);
      expect(result.value, 42);
      expect(result.attempts, 1);
    });

    test('retries on failure then succeeds', () async {
      int attempt = 0;

      final result = await ErrorRecovery.retry<String>(
        action: () async {
          attempt++;
          if (attempt < 3) {
            throw Exception('temporary error');
          }
          return 'success';
        },
        config: const RetryConfig(
          maxRetries: 5,
          initialDelay: Duration(milliseconds: 10),
          retryableErrors: {},
        ),
        label: 'retry-test',
      );

      expect(result.success, true);
      expect(result.value, 'success');
      expect(result.attempts, 3);
    });

    test('fails after max retries', () async {
      final result = await ErrorRecovery.retry<int>(
        action: () async {
          throw Exception('always fails');
        },
        config: const RetryConfig(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 10),
          retryableErrors: {},
        ),
        label: 'fail-test',
      );

      expect(result.success, false);
      expect(result.error, isNotNull);
      expect(result.attempts, 3); // initial + 2 retries
    });

    test('uses fallback on failure', () async {
      final result = await ErrorRecovery.retry<String>(
        action: () async => throw Exception('fail'),
        config: const RetryConfig(
          maxRetries: 1,
          initialDelay: Duration(milliseconds: 10),
          retryableErrors: {},
        ),
        fallback: (error, attempt) async => 'fallback_value',
        label: 'fallback-test',
      );

      expect(result.success, true);
      expect(result.value, 'fallback_value');
    });

    test('no retry config skips retries', () async {
      int attempt = 0;

      final result = await ErrorRecovery.retry<int>(
        action: () async {
          attempt++;
          throw Exception('fail');
        },
        config: RetryConfig.none,
        label: 'no-retry',
      );

      expect(result.success, false);
      expect(attempt, 1);
    });

    test('onRetry callback fires', () async {
      int retryCount = 0;

      await ErrorRecovery.retry<int>(
        action: () async {
          if (retryCount < 2) throw Exception('fail');
          return 1;
        },
        config: const RetryConfig(
          maxRetries: 3,
          initialDelay: Duration(milliseconds: 10),
          retryableErrors: {},
        ),
        onRetry: (attempt, error, delay) {
          retryCount++;
        },
        label: 'callback-test',
      );

      expect(retryCount, 2);
    });
  });
}
