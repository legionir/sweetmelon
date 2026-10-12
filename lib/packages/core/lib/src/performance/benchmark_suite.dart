import 'dart:async';

import 'package:sweetmelon/packages/core/lib/core.dart';

class BenchmarkResult {
  final String name;
  final int iterations;
  final Duration totalDuration;
  final Duration minDuration;
  final Duration maxDuration;
  final double avgMs;
  final double p50Ms;
  final double p95Ms;
  final double p99Ms;
  final List<Duration> allDurations;

  const BenchmarkResult({
    required this.name,
    required this.iterations,
    required this.totalDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.avgMs,
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.allDurations,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'iterations': iterations,
        'totalMs': totalDuration.inMilliseconds,
        'minMs': minDuration.inMilliseconds,
        'maxMs': maxDuration.inMilliseconds,
        'avgMs': avgMs,
        'p50Ms': p50Ms,
        'p95Ms': p95Ms,
        'p99Ms': p99Ms,
      };

  @override
  String toString() => '[$name] avg=${avgMs.toStringAsFixed(2)}ms '
      'p50=${p50Ms.toStringAsFixed(2)}ms '
      'p95=${p95Ms.toStringAsFixed(2)}ms '
      'p99=${p99Ms.toStringAsFixed(2)}ms '
      '(${iterations}x)';
}

class BenchmarkSuite {
  final List<BenchmarkResult> _results = [];

  /// اجرای یک benchmark
  Future<BenchmarkResult> run(
    String name,
    Future<void> Function() action, {
    int iterations = 100,
    int warmup = 5,
    bool verbose = true,
  }) async {
    BridgeLogger.info('Benchmark', 'Running: $name ($iterations iterations)');

    // Warmup
    for (int i = 0; i < warmup; i++) {
      await action();
    }

    final durations = <Duration>[];

    for (int i = 0; i < iterations; i++) {
      final sw = Stopwatch()..start();
      await action();
      sw.stop();
      durations.add(sw.elapsed);
    }

    final result = _computeResult(name, durations);
    _results.add(result);

    if (verbose) {
      BridgeLogger.info('Benchmark', result.toString());
    }

    return result;
  }

  /// اجرای چند benchmark و مقایسه
  Future<Map<String, BenchmarkResult>> compare(
    Map<String, Future<void> Function()> benchmarks, {
    int iterations = 100,
  }) async {
    final results = <String, BenchmarkResult>{};

    for (final entry in benchmarks.entries) {
      results[entry.key] = await run(
        entry.key,
        entry.value,
        iterations: iterations,
      );
    }

    _printComparison(results);
    return results;
  }

  BenchmarkResult _computeResult(
    String name,
    List<Duration> durations,
  ) {
    if (durations.isEmpty) {
      return BenchmarkResult(
        name: name,
        iterations: 0,
        totalDuration: Duration.zero,
        minDuration: Duration.zero,
        maxDuration: Duration.zero,
        avgMs: 0,
        p50Ms: 0,
        p95Ms: 0,
        p99Ms: 0,
        allDurations: [],
      );
    }

    final sorted = List<Duration>.from(durations)
      ..sort((a, b) => a.compareTo(b));

    final totalMs = durations.fold<int>(
      0,
      (sum, d) => sum + d.inMicroseconds,
    );

    final avgMs = totalMs / durations.length / 1000.0;
    final p50Ms = _percentile(sorted, 0.5).inMicroseconds / 1000.0;
    final p95Ms = _percentile(sorted, 0.95).inMicroseconds / 1000.0;
    final p99Ms = _percentile(sorted, 0.99).inMicroseconds / 1000.0;

    return BenchmarkResult(
      name: name,
      iterations: durations.length,
      totalDuration: Duration(microseconds: totalMs),
      minDuration: sorted.first,
      maxDuration: sorted.last,
      avgMs: avgMs,
      p50Ms: p50Ms,
      p95Ms: p95Ms,
      p99Ms: p99Ms,
      allDurations: durations,
    );
  }

  Duration _percentile(List<Duration> sorted, double p) {
    final index = ((sorted.length - 1) * p).round();
    return sorted[index];
  }

  void _printComparison(Map<String, BenchmarkResult> results) {
    if (results.isEmpty) return;

    final baseline = results.values.first;
    BridgeLogger.info('Benchmark', '--- Comparison ---');

    for (final entry in results.entries) {
      final ratio = entry.value.avgMs / baseline.avgMs;
      final symbol = ratio < 1
          ? '🟢'
          : ratio < 1.5
              ? '🟡'
              : '🔴';
      BridgeLogger.info(
        'Benchmark',
        '$symbol ${entry.key}: ${entry.value.avgMs.toStringAsFixed(2)}ms '
            '(${ratio.toStringAsFixed(2)}x)',
      );
    }
  }

  List<BenchmarkResult> get results => List.unmodifiable(_results);

  Map<String, dynamic> getSummaryReport() {
    return {
      'totalBenchmarks': _results.length,
      'benchmarks': _results.map((r) => r.toJson()).toList(),
    };
  }

  void clear() => _results.clear();
}
