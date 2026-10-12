import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('CircuitBreaker', () {
    late CircuitBreaker breaker;

    setUp(() {
      breaker = CircuitBreaker(
        name: 'test',
        config: const CircuitBreakerConfig(
          failureThreshold: 3,
          resetTimeout: Duration(milliseconds: 200),
        ),
      );
    });

    test('starts in closed state', () {
      expect(breaker.state, CircuitState.closed);
      expect(breaker.isAllowed, true);
    });

    test('stays closed on success', () async {
      final result = await breaker.execute(() async => 42);

      expect(result, 42);
      expect(breaker.state, CircuitState.closed);
    });

    test('opens after threshold failures', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      expect(breaker.state, CircuitState.open);
      expect(breaker.isAllowed, false);
    });

    test('rejects calls when open', () async {
      // Force open
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      expect(
        () => breaker.execute(() async => 'should not run'),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });

    test('transitions to half-open after timeout', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      expect(breaker.state, CircuitState.open);

      // Wait for reset timeout
      await Future.delayed(const Duration(milliseconds: 250));

      expect(breaker.state, CircuitState.halfOpen);
      expect(breaker.isAllowed, true);
    });

    test('closes from half-open on success', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 250));

      final result = await breaker.execute(() async => 'recovered');

      expect(result, 'recovered');
      expect(breaker.state, CircuitState.closed);
    });

    test('re-opens from half-open on failure', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 250));

      try {
        await breaker.execute(() async => throw Exception('fail again'));
      } catch (_) {}

      expect(breaker.state, CircuitState.open);
    });

    test('reset works', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      expect(breaker.state, CircuitState.open);

      breaker.reset();

      expect(breaker.state, CircuitState.closed);
      expect(breaker.isAllowed, true);
    });

    test('stats are tracked', () async {
      await breaker.execute(() async => 'ok');

      try {
        await breaker.execute(() async => throw Exception('fail'));
      } catch (_) {}

      final stats = breaker.stats;

      expect(stats['totalCalls'], 2);
      expect(stats['successCount'], 1);
      expect(stats['failureCount'], 1);
    });
  });

  group('CircuitBreakerRegistry', () {
    test('creates breakers lazily', () {
      final registry = CircuitBreakerRegistry();

      final b1 = registry.get('plugin_a');
      final b2 = registry.get('plugin_a');

      expect(identical(b1, b2), true);
    });

    test('reset specific breaker', () async {
      final registry = CircuitBreakerRegistry(
        defaultConfig: const CircuitBreakerConfig(failureThreshold: 1),
      );

      try {
        await registry.execute('test', () async => throw Exception('fail'));
      } catch (_) {}

      expect(registry.get('test').state, CircuitState.open);

      registry.reset('test');
      expect(registry.get('test').state, CircuitState.closed);
    });

    test('resetAll resets all breakers', () async {
      final registry = CircuitBreakerRegistry(
        defaultConfig: const CircuitBreakerConfig(failureThreshold: 1),
      );

      try {
        await registry.execute('a', () async => throw Exception('fail'));
      } catch (_) {}
      try {
        await registry.execute('b', () async => throw Exception('fail'));
      } catch (_) {}

      registry.resetAll();

      expect(registry.get('a').state, CircuitState.closed);
      expect(registry.get('b').state, CircuitState.closed);
    });
  });
}
