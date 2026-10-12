import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('WorkerMessage and WorkerResult', () {
    test('keep the fields they were created with', () {
      const message = WorkerMessage<int>(id: 'm1', type: 'sum', data: 42);
      const ok = WorkerResult<String>(id: 'm1', success: true, data: 'done');
      const failed = WorkerResult<String>(
        id: 'm2',
        success: false,
        error: 'boom',
      );

      expect(message.id, 'm1');
      expect(message.type, 'sum');
      expect(message.data, 42);
      expect(ok.success, true);
      expect(ok.data, 'done');
      expect(ok.error, isNull);
      expect(failed.success, false);
      expect(failed.data, isNull);
      expect(failed.error, 'boom');
    });
  });

  group('WorkerPool lifecycle', () {
    test('reports idle stats before initialization', () {
      final pool = WorkerPool(poolSize: 3);

      expect(pool.stats, {
        'poolSize': 3,
        'initialized': false,
        'activeWorkers': 0,
      });
    });

    test('initialize activates every worker once', () async {
      final pool = WorkerPool(poolSize: 2);

      await pool.initialize();
      await pool.initialize();

      expect(pool.stats['initialized'], true);
      expect(pool.stats['activeWorkers'], 2);
      pool.dispose();
    });

    test('dispose resets state so the pool can be re-initialized', () async {
      final pool = WorkerPool(poolSize: 2);
      await pool.initialize();

      pool.dispose();
      expect(pool.stats['initialized'], false);
      expect(pool.stats['activeWorkers'], 0);

      await pool.initialize();
      expect(pool.stats['activeWorkers'], 2);
      pool.dispose();
    });
  });

  group('ComputeHelper', () {
    test('encodeJsonHeavy and decodeJsonHeavy round-trip a map', () async {
      final encoded = await ComputeHelper.encodeJsonHeavy({'a': 1, 'b': 'x'});
      final decoded = await ComputeHelper.decodeJsonHeavy(encoded);

      expect(encoded, '{"a":1,"b":"x"}');
      expect(decoded, {'a': 1, 'b': 'x'});
    });

    test('decodeJsonHeavy keeps nested structures', () async {
      final decoded = await ComputeHelper.decodeJsonHeavy(
        '{"list":[1,2],"ok":true}',
      );

      expect(decoded['list'], [1, 2]);
      expect(decoded['ok'], true);
    });
  });
}
