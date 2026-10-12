import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

/// Lets the fire-and-forget _processQueue() future run to completion.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

PluginRequest request([String method = 'ping']) =>
    PluginRequest.create(plugin: 'net', method: method);

PluginResponse okResponse(PluginRequest r) =>
    PluginResponse.success(requestId: r.requestId, data: {'ok': true});

PluginResponse failResponse(PluginRequest r) => PluginResponse.failure(
      requestId: r.requestId,
      error: const PluginError(
        code: PluginErrorCode.executionError,
        message: 'boom',
      ),
    );

void main() {
  group('OfflineQueue', () {
    test('queues requests while offline without executing them', () async {
      var calls = 0;
      final queue = OfflineQueue(
        executor: (r) async {
          calls++;
          return okResponse(r);
        },
      );
      queue.setOnline(false);

      final id = queue.enqueue(request());
      await settle();

      expect(id, startsWith('q_'));
      expect(calls, 0);
      expect(queue.isOnline, false);
      expect(queue.stats['pending'], 1);
      expect(queue.pendingItems.single['method'], 'ping');
      expect(queue.pendingItems.single['status'], 'pending');
      queue.dispose();
    });

    test('processes queued items when coming back online', () async {
      var calls = 0;
      final events = <String>[];
      final queue = OfflineQueue(
        executor: (r) async {
          calls++;
          return okResponse(r);
        },
        onEvent: (event, _) => events.add(event),
      );
      queue.setOnline(false);
      queue.enqueue(request('a'));
      queue.enqueue(request('b'));

      queue.setOnline(true);
      await settle();

      expect(calls, 2);
      expect(queue.stats['pending'], 0);
      expect(queue.stats['completed'], 2);
      expect(events, contains('queue.offline'));
      expect(events, contains('queue.online'));
      expect(events.where((e) => e == 'queue.completed').length, 2);
      queue.dispose();
    });

    test('executes immediately when online and emits enqueued', () async {
      final events = <String>[];
      final queue = OfflineQueue(
        executor: (r) async => okResponse(r),
        onEvent: (event, _) => events.add(event),
      );

      queue.enqueue(request());
      await settle();

      expect(events.first, 'queue.enqueued');
      expect(queue.stats['completed'], 1);
      expect(queue.stats['online'], true);
      queue.dispose();
    });

    test('retries failing items and gives up after maxRetries', () async {
      var calls = 0;
      final events = <String>[];
      final queue = OfflineQueue(
        config: const OfflineQueueConfig(maxRetries: 2),
        executor: (r) async {
          calls++;
          return failResponse(r);
        },
        onEvent: (event, _) => events.add(event),
      );

      queue.enqueue(request());
      await settle();

      expect(calls, 2);
      expect(queue.stats['pending'], 0);
      expect(queue.stats['failed'], 1);
      expect(events, contains('queue.failed'));
      queue.dispose();
    });

    test('treats executor exceptions as failed attempts', () async {
      var calls = 0;
      final queue = OfflineQueue(
        config: const OfflineQueueConfig(maxRetries: 2),
        executor: (r) async {
          calls++;
          throw StateError('network down');
        },
      );

      queue.enqueue(request());
      await settle();

      expect(calls, 2);
      expect(queue.stats['failed'], 1);
      queue.dispose();
    });

    test('drops expired items instead of executing them', () async {
      var calls = 0;
      final events = <String>[];
      final queue = OfflineQueue(
        executor: (r) async {
          calls++;
          return okResponse(r);
        },
        onEvent: (event, _) => events.add(event),
      );
      queue.setOnline(false);
      queue.enqueue(request(), ttl: const Duration(seconds: -1));

      queue.setOnline(true);
      await settle();

      expect(calls, 0);
      expect(queue.stats['failed'], 1);
      expect(events, contains('queue.expired'));
      queue.dispose();
    });

    test('evicts the oldest item when the queue is full', () async {
      final queue = OfflineQueue(
        config: const OfflineQueueConfig(maxQueueSize: 2),
        executor: (r) async => okResponse(r),
      );
      queue.setOnline(false);
      queue.enqueue(request('first'));
      queue.enqueue(request('second'));
      queue.enqueue(request('third'));

      final methods = queue.pendingItems.map((i) => i['method']).toList();
      expect(methods, ['second', 'third']);
      expect(queue.stats['maxQueueSize'], 2);
      queue.dispose();
    });

    test('pause holds processing until resume', () async {
      var calls = 0;
      final queue = OfflineQueue(
        executor: (r) async {
          calls++;
          return okResponse(r);
        },
      );
      queue.pause();
      queue.enqueue(request());
      await settle();
      expect(calls, 0);
      expect(queue.stats['paused'], true);

      queue.resume();
      await settle();
      expect(calls, 1);
      expect(queue.stats['paused'], false);
      queue.dispose();
    });

    test('remove deletes a pending item by id', () async {
      final queue = OfflineQueue(executor: (r) async => okResponse(r));
      queue.setOnline(false);
      final id = queue.enqueue(request());

      expect(queue.remove('missing-id'), false);
      expect(queue.remove(id), true);
      expect(queue.stats['pending'], 0);
      queue.dispose();
    });

    test('clear empties pending, completed and failed lists', () async {
      final queue = OfflineQueue(executor: (r) async => okResponse(r));
      queue.enqueue(request());
      await settle();
      expect(queue.stats['completed'], 1);

      queue.clear();
      expect(queue.stats['completed'], 0);
      expect(queue.stats['pending'], 0);
      queue.dispose();
    });

    test('start schedules periodic processing while online', () async {
      var calls = 0;
      final queue = OfflineQueue(
        config: const OfflineQueueConfig(
          processInterval: Duration(milliseconds: 10),
        ),
        executor: (r) async {
          calls++;
          return okResponse(r);
        },
      );
      queue.setOnline(false);
      queue.enqueue(request());
      queue.start();
      queue.setOnline(true);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(calls, greaterThanOrEqualTo(1));
      queue.dispose();
    });
  });
}
