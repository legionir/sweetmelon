import 'dart:async';
import 'package:sweetmelon/packages/core/lib/core.dart';

class CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  DateTime lastAccessedAt;
  int hitCount;

  CacheEntry({
    required this.value,
    required this.expiresAt,
  })  : lastAccessedAt = DateTime.now(),
        hitCount = 0;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  void touch() {
    lastAccessedAt = DateTime.now();
    hitCount++;
  }
}

class CacheManager {
  final Map<String, CacheEntry> _cache = {};
  final int maxEntries;
  Timer? _cleanupTimer;

  int _hits = 0;
  int _misses = 0;

  final Set<String> _noCachePatterns = {};

  /// متدهایی که mutation هستند و نباید cache بشن
  final Set<String> _mutationMethods = {
    'set',
    'setData',
    'remove',
    'clear',
    'delete',
    'write',
    'update',
    'insert',
    'create',
    'put',
    'patch',
    'post',
    'deleteFile',
    'writeFile',
  };

  CacheManager({this.maxEntries = 500}) {
    _startCleanupTimer();
  }

  /// بررسی mutation بودن method
  bool isMutationMethod(String method) {
    return _mutationMethods.contains(method);
  }

  void addMutationMethod(String method) {
    _mutationMethods.add(method);
  }

  Future<dynamic> get(String key) async {
    final entry = _cache[key];

    if (entry == null) {
      _misses++;
      return null;
    }

    if (entry.isExpired) {
      _cache.remove(key);
      _misses++;
      return null;
    }

    entry.touch();
    _hits++;
    BridgeLogger.debug('Cache', 'Hit: $key');
    return entry.value;
  }

  Future<void> set(
    String key,
    dynamic value, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    if (_shouldSkipCache(key)) {
      BridgeLogger.debug('Cache', 'Skipped (no-cache): $key');
      return;
    }

    if (_cache.length >= maxEntries) {
      _evictLRU();
    }

    _cache[key] = CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );

    BridgeLogger.debug('Cache', 'Set: $key (TTL: ${ttl.inSeconds}s)');
  }

  Future<void> invalidate(String key) async {
    _cache.remove(key);
  }

  Future<void> invalidatePlugin(String pluginName) async {
    _cache.removeWhere((key, _) => key.startsWith('$pluginName:'));
    BridgeLogger.debug('Cache', 'Invalidated all keys for plugin: $pluginName');
  }

  Future<void> invalidatePattern(String pattern) async {
    _cache.removeWhere((key, _) => key.contains(pattern));
  }

  Future<void> clear() async {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }

  void addNoCachePattern(String pattern) {
    _noCachePatterns.add(pattern);
  }

  void removeNoCachePattern(String pattern) {
    _noCachePatterns.remove(pattern);
  }

  void _evictLRU() {
    if (_cache.isEmpty) return;

    String? lruKey;
    DateTime? oldestAccess;

    for (final entry in _cache.entries) {
      if (oldestAccess == null ||
          entry.value.lastAccessedAt.isBefore(oldestAccess)) {
        oldestAccess = entry.value.lastAccessedAt;
        lruKey = entry.key;
      }
    }

    if (lruKey != null) {
      _cache.remove(lruKey);
      BridgeLogger.debug('Cache', 'Evicted LRU: $lruKey');
    }
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _cleanup(),
    );
  }

  void _cleanup() {
    final expired = _cache.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();

    for (final key in expired) {
      _cache.remove(key);
    }

    if (expired.isNotEmpty) {
      BridgeLogger.debug('Cache', 'Cleaned ${expired.length} expired entries');
    }
  }

  bool _shouldSkipCache(String key) {
    for (final pattern in _noCachePatterns) {
      if (key.startsWith(pattern) || key.contains(pattern)) {
        return true;
      }
    }
    return false;
  }

  CacheStats get stats => CacheStats(
        entries: _cache.length,
        hits: _hits,
        misses: _misses,
        hitRate: (_hits + _misses) > 0 ? _hits / (_hits + _misses) : 0,
      );

  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}

class CacheStats {
  final int entries;
  final int hits;
  final int misses;
  final double hitRate;

  const CacheStats({
    required this.entries,
    required this.hits,
    required this.misses,
    required this.hitRate,
  });

  Map<String, dynamic> toJson() => {
        'entries': entries,
        'hits': hits,
        'misses': misses,
        'hitRate': hitRate,
      };
}
