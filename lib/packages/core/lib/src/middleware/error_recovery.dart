import 'dart:async';
import 'dart:io';

import '../utils/logger.dart';

typedef RecoverableAction<T> = Future<T> Function();
typedef FallbackProvider<T> = Future<T> Function(Object error, int attempt);

class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final Set<Type> retryableErrors;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 200),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 10),
    this.retryableErrors = const {
      TimeoutException,
      IOException,
    },
  });

  static const RetryConfig none = RetryConfig(maxRetries: 0);

  static const RetryConfig light = RetryConfig(
    maxRetries: 2,
    initialDelay: Duration(milliseconds: 100),
  );

  static const RetryConfig standard = RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(milliseconds: 300),
  );

  static const RetryConfig aggressive = RetryConfig(
    maxRetries: 5,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 30),
  );
}

class RetryResult<T> {
  final T? value;
  final Object? error;
  final int attempts;
  final Duration totalDuration;
  final bool success;

  const RetryResult({
    this.value,
    this.error,
    required this.attempts,
    required this.totalDuration,
    required this.success,
  });
}

class ErrorRecovery {
  static Future<RetryResult<T>> retry<T>({
    required RecoverableAction<T> action,
    RetryConfig config = const RetryConfig(),
    FallbackProvider<T>? fallback,
    String? label,
    void Function(int attempt, Object error, Duration nextDelay)? onRetry,
  }) async {
    final stopwatch = Stopwatch()..start();
    Object? lastError;
    int attempt = 0;

    while (attempt <= config.maxRetries) {
      attempt++;

      try {
        final result = await action();
        stopwatch.stop();

        if (attempt > 1) {
          BridgeLogger.info(
            'Retry',
            '${label ?? "action"} succeeded after $attempt attempts',
          );
        }

        return RetryResult<T>(
          value: result,
          attempts: attempt,
          totalDuration: stopwatch.elapsed,
          success: true,
        );
      } catch (e) {
        lastError = e;

        final isRetryable = _isRetryable(e, config.retryableErrors);
        final hasMoreRetries = attempt <= config.maxRetries;

        if (!isRetryable || !hasMoreRetries) {
          break;
        }

        final delay = _calculateDelay(attempt, config);

        BridgeLogger.warn(
          'Retry',
          '${label ?? "action"} failed (attempt $attempt/${config.maxRetries + 1}), '
              'retrying in ${delay.inMilliseconds}ms: $e',
        );

        onRetry?.call(attempt, e, delay);

        await Future.delayed(delay);
      }
    }

    // All retries exhausted — try fallback
    if (fallback != null) {
      try {
        BridgeLogger.info(
          'Retry',
          '${label ?? "action"} using fallback after $attempt attempts',
        );

        final result = await fallback(lastError!, attempt);
        stopwatch.stop();

        return RetryResult<T>(
          value: result,
          attempts: attempt,
          totalDuration: stopwatch.elapsed,
          success: true,
        );
      } catch (fallbackError) {
        lastError = fallbackError;
      }
    }

    stopwatch.stop();

    return RetryResult<T>(
      error: lastError,
      attempts: attempt,
      totalDuration: stopwatch.elapsed,
      success: false,
    );
  }

  static bool _isRetryable(Object error, Set<Type> retryableTypes) {
    if (retryableTypes.isEmpty) return true;

    for (final type in retryableTypes) {
      if (error.runtimeType == type) return true;
    }

    // TimeoutException check
    if (error is TimeoutException) return true;

    // Check if error message contains network-related text
    final msg = error.toString().toLowerCase();
    if (msg.contains('timeout') ||
        msg.contains('connection') ||
        msg.contains('socket') ||
        msg.contains('network')) {
      return true;
    }

    return false;
  }

  static Duration _calculateDelay(int attempt, RetryConfig config) {
    final delayMs = config.initialDelay.inMilliseconds *
        _pow(config.backoffMultiplier, attempt - 1);

    final clampedMs = delayMs.clamp(0, config.maxDelay.inMilliseconds);

    // Add jitter (±20%)
    final jitter =
        (clampedMs * 0.2 * (DateTime.now().millisecond % 10 / 10)).round();

    return Duration(milliseconds: clampedMs.round() + jitter);
  }

  static double _pow(double base, int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
