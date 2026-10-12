import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('MemoryProfiler', () {
    late MemoryProfiler profiler;

    setUp(() {
      profiler = MemoryProfiler(
        sampleInterval: const Duration(milliseconds: 50),
        maxSnapshots: 10,
      );
    });

    tearDown(() => profiler.dispose());

    test('starts and stops', () async {
      profiler.start();
      expect(profiler.snapshots.isEmpty, true);

      await Future.delayed(const Duration(milliseconds: 120));

      profiler.stop();
      expect(profiler.snapshots.isNotEmpty, true);
    });

    test('respects maxSnapshots', () async {
      profiler = MemoryProfiler(
        sampleInterval: const Duration(milliseconds: 20),
        maxSnapshots: 5,
      );

      profiler.start();
      await Future.delayed(const Duration(milliseconds: 200));
      profiler.stop();

      expect(profiler.snapshots.length, lessThanOrEqualTo(5));
    });

    test('addProvider includes data', () async {
      profiler.addProvider(_MockProvider());
      profiler.start();

      await Future.delayed(const Duration(milliseconds: 120));
      profiler.stop();

      final snapshot = profiler.snapshots.first;
      expect(snapshot.activeCalls, 42);
    });

    test('getSummary returns data after sampling', () async {
      profiler.start();
      await Future.delayed(const Duration(milliseconds: 120));
      profiler.stop();

      final summary = profiler.getSummary();
      expect(summary['samples'], greaterThan(0));
      expect(summary['running'], false);
    });
  });
}

class _MockProvider implements MemoryDataProvider {
  @override
  Map<String, dynamic> getMemoryData() => {
        'activeCalls': 42,
        'cachedItems': 10,
        'activeStreams': 0,
        'registeredPlugins': 5,
      };
}
