import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/performance/lib/performance.dart';

void main() {
  group('CacheManager', () {
    late CacheManager cache;

    setUp(() {
      cache = CacheManager(maxEntries: 10);
    });

    tearDown(() {
      cache.dispose();
    });

    test('set and get', () async {
      await cache.set('key1', 'value1');
      final result = await cache.get('key1');

      expect(result, 'value1');
    });

    test('get returns null for missing key', () async {
      final result = await cache.get('nonexistent');
      expect(result, isNull);
    });

    test('TTL expiration', () async {
      await cache.set(
        'expiring',
        'value',
        ttl: const Duration(milliseconds: 100),
      );

      var result = await cache.get('expiring');
      expect(result, 'value');

      await Future.delayed(const Duration(milliseconds: 150));

      result = await cache.get('expiring');
      expect(result, isNull);
    });

    test('invalidate removes key', () async {
      await cache.set('key1', 'value1');
      await cache.invalidate('key1');

      final result = await cache.get('key1');
      expect(result, isNull);
    });

    test('invalidatePlugin removes plugin keys', () async {
      await cache.set('storage:get:key1', 'v1');
      await cache.set('storage:get:key2', 'v2');
      await cache.set('camera:info', 'v3');

      await cache.invalidatePlugin('storage');

      expect(await cache.get('storage:get:key1'), isNull);
      expect(await cache.get('storage:get:key2'), isNull);
      expect(await cache.get('camera:info'), 'v3');
    });

    test('LRU eviction', () async {
      final smallCache = CacheManager(maxEntries: 3);

      await smallCache.set('a', 1);
      await smallCache.set('b', 2);
      await smallCache.set('c', 3);

      // Touch 'a' to make 'b' the LRU
      await smallCache.get('a');

      await smallCache.set('d', 4); // evicts 'b'

      expect(await smallCache.get('b'), isNull);
      expect(await smallCache.get('a'), 1);
      expect(await smallCache.get('c'), 3);
      expect(await smallCache.get('d'), 4);

      smallCache.dispose();
    });

    test('clear removes all entries', () async {
      await cache.set('a', 1);
      await cache.set('b', 2);

      await cache.clear();

      expect(await cache.get('a'), isNull);
      expect(await cache.get('b'), isNull);
      expect(cache.stats.entries, 0);
    });

    test('stats tracking', () async {
      await cache.set('key1', 'value1');

      await cache.get('key1'); // hit
      await cache.get('key1'); // hit
      await cache.get('missing'); // miss

      final stats = cache.stats;

      expect(stats.hits, 2);
      expect(stats.misses, 1);
      expect(stats.entries, 1);
      expect(stats.hitRate, closeTo(0.667, 0.01));
    });

    test('isMutationMethod detects mutations', () {
      expect(cache.isMutationMethod('set'), true);
      expect(cache.isMutationMethod('remove'), true);
      expect(cache.isMutationMethod('clear'), true);
      expect(cache.isMutationMethod('writeFile'), true);
      expect(cache.isMutationMethod('get'), false);
      expect(cache.isMutationMethod('keys'), false);
    });

    test('noCachePattern skips cache', () async {
      cache.addNoCachePattern('nocache:');

      await cache.set('nocache:key1', 'value');
      final result = await cache.get('nocache:key1');

      expect(result, isNull); // was skipped
    });
  });
}
