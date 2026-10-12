import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('PerformanceAudit', () {
    late PerformanceAudit audit;

    setUp(() {
      audit = PerformanceAudit(maxMetrics: 100);
    });

    test('record adds metrics', () async {
      audit.record(PerformanceMetric(
        name: 'test',
        category: 'plugin',
        durationMs: 100,
        success: true,
        timestamp: DateTime.now(),
      ));

      expect(audit.metrics.length, 1);
    });

    test('measure wraps async fn', () async {
      final result = await audit.measure(
        name: 'test_op',
        category: 'test',
        fn: () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 42;
        },
      );

      expect(result, 42);
      expect(audit.metrics.length, 1);
      expect(audit.metrics.first.durationMs, greaterThanOrEqualTo(10));
      expect(audit.metrics.first.success, true);
    });

    test('measure records failure', () async {
      try {
        await audit.measure(
          name: 'failing_op',
          category: 'test',
          fn: () async {
            throw Exception('test error');
          },
        );
      } catch (_) {}

      expect(audit.metrics.first.success, false);
    });

    test('generateReport with data', () {
      for (int i = 0; i < 20; i++) {
        audit.record(PerformanceMetric(
          name: 'op_$i',
          category: 'plugin',
          durationMs: i * 50,
          success: i % 5 != 0,
          timestamp: DateTime.now(),
        ));
      }

      final report = audit.generateReport();

      expect(report.totalOperations, 20);
      expect(report.successRate, lessThanOrEqualTo(100));
      expect(report.avgDurationMs, greaterThan(0));
      expect(report.p95DurationMs, greaterThanOrEqualTo(report.avgDurationMs));
      expect(report.slowestOperations, isNotEmpty);
    });

    test('generateReport empty returns zeros', () {
      final report = audit.generateReport();
      expect(report.totalOperations, 0);
      expect(report.recommendations, isNotEmpty);
    });

    test('respects maxMetrics', () {
      for (int i = 0; i < 150; i++) {
        audit.record(PerformanceMetric(
          name: 'op',
          category: 'test',
          durationMs: 100,
          success: true,
          timestamp: DateTime.now(),
        ));
      }
      expect(audit.metrics.length, 100);
    });

    test('recommendations for slow operations', () {
      for (int i = 0; i < 10; i++) {
        audit.record(PerformanceMetric(
          name: 'slow',
          category: 'network',
          durationMs: 3000,
          success: true,
          timestamp: DateTime.now(),
        ));
      }

      final report = audit.generateReport();
      expect(
        report.recommendations
            .any((r) => r.contains('P95') || r.contains('Average')),
        true,
      );
    });

    test('recommendations for low success rate', () {
      for (int i = 0; i < 20; i++) {
        audit.record(PerformanceMetric(
          name: 'op',
          category: 'plugin',
          durationMs: 100,
          success: i < 8, // 40% success
          timestamp: DateTime.now(),
        ));
      }

      final report = audit.generateReport();
      expect(
        report.recommendations.any((r) => r.contains('Success rate')),
        true,
      );
    });

    test('toJson is valid', () {
      audit.record(PerformanceMetric(
        name: 'test',
        category: 'plugin',
        durationMs: 100,
        success: true,
        timestamp: DateTime.now(),
      ));

      final report = audit.generateReport();
      final json = report.toJson();

      expect(json['totalOperations'], isA<int>());
      expect(json['successRate'], isA<double>());
      expect(json['recommendations'], isA<List>());
      expect(json['generatedAt'], isNotNull);
    });
  });
}
