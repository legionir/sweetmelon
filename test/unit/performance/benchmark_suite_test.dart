import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('BenchmarkSuite', () {
    late BenchmarkSuite suite;

    setUp(() => suite = BenchmarkSuite());
    tearDown(() => suite.clear());

    test('run returns BenchmarkResult', () async {
      final result = await suite.run(
        'test_op',
        () async => await Future.delayed(Duration.zero),
        iterations: 10,
        warmup: 2,
        verbose: false,
      );

      expect(result.name, 'test_op');
      expect(result.iterations, 10);
      expect(result.avgMs, greaterThanOrEqualTo(0));
      expect(result.p50Ms, greaterThanOrEqualTo(0));
      expect(result.p95Ms, greaterThanOrEqualTo(result.p50Ms));
      expect(result.p99Ms, greaterThanOrEqualTo(result.p95Ms));
    });

    test('faster operation has lower avgMs', () async {
      final fast = await suite.run(
        'fast',
        () async {},
        iterations: 20,
        verbose: false,
      );

      final slow = await suite.run(
        'slow',
        () async => await Future.delayed(const Duration(milliseconds: 10)),
        iterations: 5,
        verbose: false,
      );

      expect(slow.avgMs, greaterThan(fast.avgMs));
    });

    test('compare returns results for all benchmarks', () async {
      final results = await suite.compare(
        {
          'op1': () async {},
          'op2': () async => await Future.delayed(Duration.zero),
        },
        iterations: 5,
      );

      expect(results.length, 2);
      expect(results.containsKey('op1'), true);
      expect(results.containsKey('op2'), true);
    });

    test('getSummaryReport contains all results', () async {
      await suite.run('a', () async {}, iterations: 5, verbose: false);
      await suite.run('b', () async {}, iterations: 5, verbose: false);

      final report = suite.getSummaryReport();
      expect(report['totalBenchmarks'], 2);
    });

    test('toJson works', () async {
      final result = await suite.run(
        'json_test',
        () async {},
        iterations: 10,
        verbose: false,
      );

      final json = result.toJson();
      expect(json['name'], 'json_test');
      expect(json['iterations'], 10);
      expect(json['avgMs'], isA<double>());
      expect(json['p95Ms'], isA<double>());
    });

    test('percentile ordering is correct', () async {
      final result = await suite.run(
        'percentile',
        () async {},
        iterations: 50,
        verbose: false,
      );

      expect(result.p50Ms, lessThanOrEqualTo(result.p95Ms));
      expect(result.p95Ms, lessThanOrEqualTo(result.p99Ms));
      expect(result.minDuration, lessThanOrEqualTo(result.maxDuration));
    });
  });
}
