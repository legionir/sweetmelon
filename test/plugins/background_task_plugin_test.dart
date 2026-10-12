import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/background_task/lib/background_task_plugin.dart';

void main() {
  group('BackgroundTaskPlugin', () {
    late BackgroundTaskPlugin plugin;
    final List<Map<String, dynamic>> events = [];

    setUp(() async {
      events.clear();
      plugin = BackgroundTaskPlugin(
        eventEmitter: (event, data) async {
          events.add({'event': event, 'data': data});
        },
      );
      await plugin.initialize();
    });

    tearDown(() async {
      await plugin.dispose();
    });

    test('register task', () async {
      final result = await plugin.onCall('register', {
        'taskId': 'sync_task',
        'name': 'Data Sync',
      });

      expect(result['registered'], true);
      expect(result['taskId'], 'sync_task');
    });

    test('runOnce executes task', () async {
      await plugin.onCall('register', {'taskId': 'test_task'});

      final result = await plugin.onCall('runOnce', {
        'taskId': 'test_task',
        'action': 'compute',
        'params': {'expression': '1+1'},
      });

      expect(result['completed'], true);
      expect(result['taskId'], 'test_task');

      // events fired
      expect(
        events.any((e) => e['event'] == 'task.started'),
        true,
      );
      expect(
        events.any((e) => e['event'] == 'task.completed'),
        true,
      );
    });

    test('getTaskState returns correct state', () async {
      await plugin.onCall('register', {'taskId': 'state_task'});
      await plugin.onCall('runOnce', {
        'taskId': 'state_task',
        'action': 'execute',
      });

      final state = await plugin.onCall('getTaskState', {
        'taskId': 'state_task',
      });

      expect(state['found'], true);
      expect(state['runCount'], 1);
      expect(state['status'], 'completed');
    });

    test('getAllTasks returns all registered tasks', () async {
      await plugin.onCall('register', {'taskId': 'a'});
      await plugin.onCall('register', {'taskId': 'b'});

      final result = await plugin.onCall('getAllTasks', {});

      expect(result['count'], 2);
    });

    test('unregister removes task', () async {
      await plugin.onCall('register', {'taskId': 'temp'});

      final result = await plugin.onCall('unregister', {
        'taskId': 'temp',
      });

      expect(result['unregistered'], true);

      final all = await plugin.onCall('getAllTasks', {});
      expect(all['count'], 0);
    });

    test('validates taskId required', () async {
      final r = await plugin.validateArgs('register', {});
      expect(r.isValid, false);
    });

    test('validates intervalMs for repeating', () async {
      final r1 = await plugin.validateArgs('startRepeating', {
        'taskId': 'x',
      });
      expect(r1.isValid, false);

      final r2 = await plugin.validateArgs('startRepeating', {
        'taskId': 'x',
        'intervalMs': 500,
      });
      expect(r2.isValid, false); // min 1000ms

      final r3 = await plugin.validateArgs('startRepeating', {
        'taskId': 'x',
        'intervalMs': 5000,
      });
      expect(r3.isValid, true);
    });

    test('stopAll cancels all timers', () async {
      await plugin.onCall('register', {'taskId': 'r1'});
      await plugin.onCall('startRepeating', {
        'taskId': 'r1',
        'intervalMs': 60000,
        'immediate': false,
      });

      final result = await plugin.onCall('stopAll', {});
      expect(result['stopped'], 1);
    });
  });
}
