import 'dart:async';

import '../utils/logger.dart';

class MemorySnapshot {
  final DateTime timestamp;
  final int activeCalls;
  final int cachedItems;
  final int activeStreams;
  final int registeredPlugins;
  final Map<String, dynamic> extra;

  const MemorySnapshot({
    required this.timestamp,
    required this.activeCalls,
    required this.cachedItems,
    required this.activeStreams,
    required this.registeredPlugins,
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'activeCalls': activeCalls,
        'cachedItems': cachedItems,
        'activeStreams': activeStreams,
        'registeredPlugins': registeredPlugins,
        ...extra,
      };
}

class MemoryProfiler {
  final Duration sampleInterval;
  final int maxSnapshots;

  Timer? _timer;
  final List<MemorySnapshot> _snapshots = [];
  final List<MemoryDataProvider> _providers = [];
  bool _running = false;

  MemoryProfiler({
    this.sampleInterval = const Duration(seconds: 10),
    this.maxSnapshots = 100,
  });

  void addProvider(MemoryDataProvider provider) {
    _providers.add(provider);
  }

  void start() {
    if (_running) return;
    _running = true;

    _timer = Timer.periodic(sampleInterval, (_) => _sample());
    BridgeLogger.info('MemoryProfiler', 'Started profiling');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  void _sample() {
    int activeCalls = 0;
    int cachedItems = 0;
    int activeStreams = 0;
    int registeredPlugins = 0;
    final extra = <String, dynamic>{};

    for (final provider in _providers) {
      try {
        final data = provider.getMemoryData();
        activeCalls += data['activeCalls'] as int? ?? 0;
        cachedItems += data['cachedItems'] as int? ?? 0;
        activeStreams += data['activeStreams'] as int? ?? 0;
        registeredPlugins += data['registeredPlugins'] as int? ?? 0;

        data.forEach((key, value) {
          if (![
            'activeCalls',
            'cachedItems',
            'activeStreams',
            'registeredPlugins'
          ].contains(key)) {
            extra[key] = value;
          }
        });
      } catch (e) {
        BridgeLogger.warn('MemoryProfiler', 'Provider error: $e');
      }
    }

    final snapshot = MemorySnapshot(
      timestamp: DateTime.now(),
      activeCalls: activeCalls,
      cachedItems: cachedItems,
      activeStreams: activeStreams,
      registeredPlugins: registeredPlugins,
      extra: extra,
    );

    _snapshots.add(snapshot);

    if (_snapshots.length > maxSnapshots) {
      _snapshots.removeAt(0);
    }

    _detectAnomalies(snapshot);
  }

  void _detectAnomalies(MemorySnapshot snapshot) {
    if (snapshot.activeCalls > 100) {
      BridgeLogger.warn(
        'MemoryProfiler',
        'High active calls: ${snapshot.activeCalls}',
      );
    }

    if (snapshot.cachedItems > 400) {
      BridgeLogger.warn(
        'MemoryProfiler',
        'Cache near capacity: ${snapshot.cachedItems}/500',
      );
    }
  }

  List<MemorySnapshot> get snapshots => List.unmodifiable(_snapshots);

  Map<String, dynamic> getSummary() {
    if (_snapshots.isEmpty) return {'samples': 0};

    final last = _snapshots.last;
    final first = _snapshots.first;

    final callsTrend =
        _snapshots.length > 1 ? last.activeCalls - first.activeCalls : 0;

    final avgCachedItems = _snapshots.isEmpty
        ? 0
        : _snapshots.map((s) => s.cachedItems).reduce((a, b) => a + b) ~/
            _snapshots.length;

    return {
      'samples': _snapshots.length,
      'running': _running,
      'latest': last.toJson(),
      'trends': {
        'activeCalls': callsTrend >= 0 ? '+$callsTrend' : '$callsTrend',
      },
      'averages': {
        'cachedItems': avgCachedItems,
      },
    };
  }

  void dispose() {
    stop();
    _snapshots.clear();
    _providers.clear();
  }
}

abstract class MemoryDataProvider {
  Map<String, dynamic> getMemoryData();
}
