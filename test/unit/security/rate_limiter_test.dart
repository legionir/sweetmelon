import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/security/lib/security.dart';

void main() {
  group('RateLimiter', () {
    late RateLimiter limiter;

    setUp(() {
      limiter = RateLimiter();
    });

    test('allows calls within limit', () async {
      limiter.addRule('test', RateLimitRule.perSecond(5));

      for (int i = 0; i < 5; i++) {
        final result = await limiter.check('test', 'method');
        expect(result.allowed, true);
      }
    });

    test('blocks calls exceeding limit', () async {
      limiter.addRule('test', RateLimitRule.perSecond(3));

      for (int i = 0; i < 3; i++) {
        await limiter.check('test', 'method');
      }

      final result = await limiter.check('test', 'method');
      expect(result.allowed, false);
      expect(result.remaining, 0);
      expect(result.retryAfterMs, greaterThan(0));
    });

    test('resets after window', () async {
      limiter.addRule(
          'test',
          const RateLimitRule(
            maxCalls: 2,
            window: Duration(milliseconds: 100),
          ));

      await limiter.check('test', 'method');
      await limiter.check('test', 'method');

      var result = await limiter.check('test', 'method');
      expect(result.allowed, false);

      await Future.delayed(const Duration(milliseconds: 150));

      result = await limiter.check('test', 'method');
      expect(result.allowed, true);
    });

    test('uses default rule when no specific rule', () async {
      limiter.setDefaultRule(RateLimitRule.perSecond(100));

      final result = await limiter.check('unknown', 'method');
      expect(result.allowed, true);
    });

    test('per-method rules override plugin rules', () async {
      limiter.addRule('plugin', RateLimitRule.perSecond(100));
      limiter.addRule('plugin.heavyMethod', RateLimitRule.perSecond(2));

      // Heavy method limited to 2
      await limiter.check('plugin', 'heavyMethod');
      await limiter.check('plugin', 'heavyMethod');
      final result = await limiter.check('plugin', 'heavyMethod');
      expect(result.allowed, false);
    });

    test('reset clears specific key', () async {
      limiter.addRule('test', RateLimitRule.perSecond(1));

      await limiter.check('test', 'method');
      var result = await limiter.check('test', 'method');
      expect(result.allowed, false);

      limiter.reset('test.method');

      result = await limiter.check('test', 'method');
      expect(result.allowed, true);
    });
  });
}
