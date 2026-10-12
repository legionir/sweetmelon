import 'dart:async';

class PerformanceMetric {
  final String name;
  final String category;
  final int durationMs;
  final bool success;
  final DateTime timestamp;
  final Map<String, dynamic> extra;

  const PerformanceMetric({
    required this.name,
    required this.category,
    required this.durationMs,
    required this.success,
    required this.timestamp,
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'durationMs': durationMs,
        'success': success,
        'timestamp': timestamp.toIso8601String(),
        ...extra,
      };
}

class PerformanceAudit {
  final List<PerformanceMetric> _metrics = [];
  final int _maxMetrics;

  PerformanceAudit({int maxMetrics = 1000}) : _maxMetrics = maxMetrics;

  void record(PerformanceMetric metric) {
    _metrics.add(metric);
    if (_metrics.length > _maxMetrics) {
      _metrics.removeAt(0);
    }
  }

  Future<T> measure<T>({
    required String name,
    required String category,
    required Future<T> Function() fn,
  }) async {
    final stopwatch = Stopwatch()..start();
    bool success = true;

    try {
      final result = await fn();
      stopwatch.stop();
      return result;
    } catch (e) {
      success = false;
      stopwatch.stop();
      rethrow;
    } finally {
      record(PerformanceMetric(
        name: name,
        category: category,
        durationMs: stopwatch.elapsedMilliseconds,
        success: success,
        timestamp: DateTime.now(),
      ));
    }
  }

  AuditReport generateReport() {
    if (_metrics.isEmpty) {
      return const AuditReport(
        totalOperations: 0,
        successRate: 0,
        avgDurationMs: 0,
        p95DurationMs: 0,
        p99DurationMs: 0,
        slowestOperations: [],
        categoryBreakdown: {},
        recommendations: ['ℹ️ No metrics recorded yet — collect more data'],
      );
    }

    final sorted = List<PerformanceMetric>.from(_metrics)
      ..sort((a, b) => a.durationMs.compareTo(b.durationMs));

    final successCount = _metrics.where((m) => m.success).length;
    final successRate = successCount / _metrics.length * 100;

    final avgDuration =
        _metrics.map((m) => m.durationMs).reduce((a, b) => a + b) /
            _metrics.length;

    final p95Index = (sorted.length * 0.95).round().clamp(0, sorted.length - 1);
    final p99Index = (sorted.length * 0.99).round().clamp(0, sorted.length - 1);

    // Category breakdown
    final categories = <String, List<PerformanceMetric>>{};
    for (final metric in _metrics) {
      categories.putIfAbsent(metric.category, () => []);
      categories[metric.category]!.add(metric);
    }

    final breakdown = categories.map((cat, metrics) {
      final avg = metrics.map((m) => m.durationMs).reduce((a, b) => a + b) /
          metrics.length;
      return MapEntry(cat, {
        'count': metrics.length,
        'avgMs': avg.round(),
        'successRate':
            (metrics.where((m) => m.success).length / metrics.length * 100)
                .round(),
      });
    });

    // Slowest operations
    final slowest = sorted.reversed.take(10).map((m) => m.toJson()).toList();

    // Recommendations
    final recommendations = _generateRecommendations(
      successRate: successRate,
      avgDuration: avgDuration,
      p95Duration: sorted[p95Index].durationMs.toDouble(),
      categories: categories,
    );

    return AuditReport(
      totalOperations: _metrics.length,
      successRate: successRate,
      avgDurationMs: avgDuration,
      p95DurationMs: sorted[p95Index].durationMs.toDouble(),
      p99DurationMs: sorted[p99Index].durationMs.toDouble(),
      slowestOperations: slowest,
      categoryBreakdown: breakdown,
      recommendations: recommendations,
    );
  }

  List<String> _generateRecommendations({
    required double successRate,
    required double avgDuration,
    required double p95Duration,
    required Map<String, List<PerformanceMetric>> categories,
  }) {
    final recs = <String>[];

    if (successRate < 95) {
      recs.add(
          '⚠️ Success rate is ${successRate.toStringAsFixed(1)}% — investigate failing operations');
    }

    if (avgDuration > 1000) {
      recs.add(
          '🐌 Average duration is ${avgDuration.round()}ms — consider caching or optimization');
    }

    if (p95Duration > 3000) {
      recs.add(
          '🔴 P95 duration is ${p95Duration.round()}ms — some operations are very slow');
    }

    for (final entry in categories.entries) {
      final avg = entry.value.map((m) => m.durationMs).reduce((a, b) => a + b) /
          entry.value.length;
      if (avg > 2000) {
        recs.add(
            '📌 ${entry.key} category has high avg duration (${avg.round()}ms)');
      }
    }

    if (recs.isEmpty) {
      recs.add('✅ Performance looks good!');
    }

    return recs;
  }

  void clear() => _metrics.clear();

  List<PerformanceMetric> get metrics => List.unmodifiable(_metrics);
}

class AuditReport {
  final int totalOperations;
  final double successRate;
  final double avgDurationMs;
  final double p95DurationMs;
  final double p99DurationMs;
  final List<Map<String, dynamic>> slowestOperations;
  final Map<String, Map<String, dynamic>> categoryBreakdown;
  final List<String> recommendations;

  const AuditReport({
    required this.totalOperations,
    required this.successRate,
    required this.avgDurationMs,
    required this.p95DurationMs,
    required this.p99DurationMs,
    required this.slowestOperations,
    required this.categoryBreakdown,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
        'totalOperations': totalOperations,
        'successRate': successRate,
        'avgDurationMs': avgDurationMs,
        'p95DurationMs': p95DurationMs,
        'p99DurationMs': p99DurationMs,
        'slowestOperations': slowestOperations,
        'categoryBreakdown': categoryBreakdown,
        'recommendations': recommendations,
        'generatedAt': DateTime.now().toIso8601String(),
      };

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('═══ Performance Audit Report ═══');
    buf.writeln('Total operations : $totalOperations');
    buf.writeln('Success rate     : ${successRate.toStringAsFixed(1)}%');
    buf.writeln('Avg duration     : ${avgDurationMs.round()}ms');
    buf.writeln('P95 duration     : ${p95DurationMs.round()}ms');
    buf.writeln('P99 duration     : ${p99DurationMs.round()}ms');
    buf.writeln('');
    buf.writeln('Recommendations:');
    for (final rec in recommendations) {
      buf.writeln('  $rec');
    }
    return buf.toString();
  }
}
