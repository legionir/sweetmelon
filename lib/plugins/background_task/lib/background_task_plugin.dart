import 'dart:async';
import 'dart:isolate';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef BgEventEmitter = Future<void> Function(String event, dynamic data);

/// تعریف یک task
class TaskDefinition {
  final String id;
  final String name;
  final Future<dynamic> Function(Map<String, dynamic> params) execute;
  final Duration? interval;
  final bool repeating;
  final Map<String, dynamic> params;

  const TaskDefinition({
    required this.id,
    required this.name,
    required this.execute,
    this.interval,
    this.repeating = false,
    this.params = const {},
  });
}

enum TaskStatus {
  idle,
  running,
  completed,
  failed,
  cancelled,
}

class TaskState {
  final String id;
  final String name;
  TaskStatus status;
  int runCount;
  DateTime? lastRunAt;
  DateTime? nextRunAt;
  Duration? lastDuration;
  String? lastError;
  dynamic lastResult;

  TaskState({
    required this.id,
    required this.name,
    this.status = TaskStatus.idle,
    this.runCount = 0,
    this.lastRunAt,
    this.nextRunAt,
    this.lastDuration,
    this.lastError,
    this.lastResult,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'runCount': runCount,
        'lastRunAt': lastRunAt?.toIso8601String(),
        'nextRunAt': nextRunAt?.toIso8601String(),
        'lastDurationMs': lastDuration?.inMilliseconds,
        'lastError': lastError,
      };
}

class BackgroundTaskPlugin extends Plugin {
  final BgEventEmitter? eventEmitter;

  final Map<String, TaskDefinition> _taskDefinitions = {};
  final Map<String, TaskState> _taskStates = {};
  final Map<String, Timer> _timers = {};

  BackgroundTaskPlugin({this.eventEmitter});

  @override
  String get name => 'backgroundTask';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Background task scheduler and executor plugin';

  @override
  List<String> get supportedMethods => [
        'register',
        'unregister',
        'runOnce',
        'startRepeating',
        'stop',
        'stopAll',
        'getTaskState',
        'getAllTasks',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _taskDefinitions.clear();
    _taskStates.clear();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'register':
        return _register(args);
      case 'unregister':
        return _unregister(args);
      case 'runOnce':
        return _runOnce(args);
      case 'startRepeating':
        return _startRepeating(args);
      case 'stop':
        return _stop(args);
      case 'stopAll':
        return _stopAll();
      case 'getTaskState':
        return _getTaskState(args);
      case 'getAllTasks':
        return _getAllTasks();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'registeredTasks': _taskDefinitions.length,
          'runningTimers': _timers.length,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _register(Map<String, dynamic> args) {
    final taskId = args['taskId'] as String;
    final taskName = args['name'] as String? ?? taskId;
    final params = (args['params'] as Map<String, dynamic>?) ?? {};

    // Task definition — the actual execution will come from JS via runOnce
    _taskDefinitions[taskId] = TaskDefinition(
      id: taskId,
      name: taskName,
      execute: (p) async => null, // placeholder
      params: params,
    );

    _taskStates[taskId] = TaskState(
      id: taskId,
      name: taskName,
    );

    BridgeLogger.info('BackgroundTask', 'Registered: $taskId ($taskName)');

    return {
      'registered': true,
      'taskId': taskId,
      'name': taskName,
    };
  }

  Map<String, dynamic> _unregister(Map<String, dynamic> args) {
    final taskId = args['taskId'] as String;

    _timers[taskId]?.cancel();
    _timers.remove(taskId);
    _taskDefinitions.remove(taskId);
    _taskStates.remove(taskId);

    return {'unregistered': true, 'taskId': taskId};
  }

  Future<Map<String, dynamic>> _runOnce(Map<String, dynamic> args) async {
    final taskId = args['taskId'] as String;
    final action = args['action'] as String? ?? 'execute';
    final params = (args['params'] as Map<String, dynamic>?) ?? {};
    final timeoutMs = (args['timeoutMs'] as num?)?.toInt() ?? 30000;

    final state = _taskStates[taskId];
    if (state == null) {
      // Auto-register
      _register({'taskId': taskId, 'name': taskId});
    }

    final taskState = _taskStates[taskId]!;

    if (taskState.status == TaskStatus.running) {
      return {
        'taskId': taskId,
        'started': false,
        'reason': 'already_running',
      };
    }

    taskState.status = TaskStatus.running;
    taskState.lastRunAt = DateTime.now();
    taskState.runCount++;

    _emitEvent('task.started', {
      'taskId': taskId,
      'action': action,
      'runCount': taskState.runCount,
    });

    final stopwatch = Stopwatch()..start();

    try {
      // اجرای task بر اساس action type
      dynamic result;

      switch (action) {
        case 'httpSync':
          result = await _executeHttpSync(params, timeoutMs);
          break;
        case 'storageCleanup':
          result = await _executeStorageCleanup(params);
          break;
        case 'cacheCleanup':
          result = await _executeCacheCleanup(params);
          break;
        case 'compute':
          result = await _executeCompute(params, timeoutMs);
          break;
        default:
          // Custom action — result comes from params
          result = {
            'action': action,
            'params': params,
            'executedAt': DateTime.now().toIso8601String(),
          };
      }

      stopwatch.stop();

      taskState.status = TaskStatus.completed;
      taskState.lastDuration = stopwatch.elapsed;
      taskState.lastResult = result;
      taskState.lastError = null;

      _emitEvent('task.completed', {
        'taskId': taskId,
        'durationMs': stopwatch.elapsedMilliseconds,
        'result': result,
      });

      return {
        'taskId': taskId,
        'completed': true,
        'durationMs': stopwatch.elapsedMilliseconds,
        'result': result,
      };
    } catch (e) {
      stopwatch.stop();

      taskState.status = TaskStatus.failed;
      taskState.lastDuration = stopwatch.elapsed;
      taskState.lastError = e.toString();

      BridgeLogger.error('BackgroundTask', '[$taskId] Failed: $e');

      _emitEvent('task.failed', {
        'taskId': taskId,
        'error': e.toString(),
        'durationMs': stopwatch.elapsedMilliseconds,
      });

      return {
        'taskId': taskId,
        'completed': false,
        'error': e.toString(),
      };
    }
  }

  Map<String, dynamic> _startRepeating(Map<String, dynamic> args) {
    final taskId = args['taskId'] as String;
    final intervalMs = (args['intervalMs'] as num).toInt();
    final action = args['action'] as String? ?? 'execute';
    final params = (args['params'] as Map<String, dynamic>?) ?? {};
    final immediate = args['immediate'] as bool? ?? true;

    // Cancel existing timer
    _timers[taskId]?.cancel();

    // Auto-register if needed
    if (!_taskStates.containsKey(taskId)) {
      _register({'taskId': taskId, 'name': taskId});
    }

    final taskState = _taskStates[taskId]!;
    taskState.nextRunAt = DateTime.now().add(
      Duration(milliseconds: intervalMs),
    );

    _timers[taskId] = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) {
        _runOnce({
          'taskId': taskId,
          'action': action,
          'params': params,
        });

        taskState.nextRunAt = DateTime.now().add(
          Duration(milliseconds: intervalMs),
        );
      },
    );

    BridgeLogger.info(
      'BackgroundTask',
      '[$taskId] Repeating every ${intervalMs}ms',
    );

    // Run immediately if requested
    if (immediate) {
      _runOnce({
        'taskId': taskId,
        'action': action,
        'params': params,
      });
    }

    return {
      'taskId': taskId,
      'repeating': true,
      'intervalMs': intervalMs,
    };
  }

  Map<String, dynamic> _stop(Map<String, dynamic> args) {
    final taskId = args['taskId'] as String;

    _timers[taskId]?.cancel();
    _timers.remove(taskId);

    final state = _taskStates[taskId];
    if (state != null) {
      state.status = TaskStatus.cancelled;
      state.nextRunAt = null;
    }

    return {'taskId': taskId, 'stopped': true};
  }

  Map<String, dynamic> _stopAll() {
    final count = _timers.length;

    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();

    for (final state in _taskStates.values) {
      if (state.status == TaskStatus.running) {
        state.status = TaskStatus.cancelled;
      }
      state.nextRunAt = null;
    }

    return {'stopped': count};
  }

  Map<String, dynamic> _getTaskState(Map<String, dynamic> args) {
    final taskId = args['taskId'] as String;
    final state = _taskStates[taskId];

    if (state == null) {
      return {'taskId': taskId, 'found': false};
    }

    return {
      'found': true,
      ...state.toJson(),
      'hasTimer': _timers.containsKey(taskId),
    };
  }

  Map<String, dynamic> _getAllTasks() {
    return {
      'tasks': _taskStates.values
          .map((s) => {
                ...s.toJson(),
                'hasTimer': _timers.containsKey(s.id),
              })
          .toList(),
      'count': _taskStates.length,
      'runningTimers': _timers.length,
    };
  }

  // ── Built-in task executors ──

  Future<Map<String, dynamic>> _executeHttpSync(
    Map<String, dynamic> params,
    int timeoutMs,
  ) async {
    // این task داده‌ها رو از یه URL می‌خونه و sync می‌کنه
    final url = params['url'] as String?;
    if (url == null) {
      return {'synced': false, 'reason': 'no_url'};
    }

    BridgeLogger.info('BackgroundTask', 'HTTP Sync: $url');

    // در عمل اینجا باید از HTTP plugin استفاده بشه
    // ولی چون داخل همین Dart هستیم:
    return {
      'synced': true,
      'url': url,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeStorageCleanup(
    Map<String, dynamic> params,
  ) async {
    final olderThanDays = (params['olderThanDays'] as num?)?.toInt() ?? 30;

    BridgeLogger.info(
      'BackgroundTask',
      'Storage cleanup: older than $olderThanDays days',
    );

    return {
      'cleaned': true,
      'olderThanDays': olderThanDays,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeCacheCleanup(
    Map<String, dynamic> params,
  ) async {
    BridgeLogger.info('BackgroundTask', 'Cache cleanup');

    return {
      'cleaned': true,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _executeCompute(
    Map<String, dynamic> params,
    int timeoutMs,
  ) async {
    // اجرای یک محاسبه سنگین در isolate جداگانه
    final expression = params['expression'] as String?;
    final data = params['data'];

    if (expression == null) {
      return {'computed': false, 'reason': 'no_expression'};
    }

    try {
      final result = await Isolate.run(() {
        // محاسبه ساده — در عمل می‌شه پیچیده‌تر باشه
        return {
          'expression': expression,
          'data': data,
          'result': 'computed',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }).timeout(Duration(milliseconds: timeoutMs));

      return {
        'computed': true,
        'result': result,
      };
    } on TimeoutException {
      return {'computed': false, 'reason': 'timeout'};
    }
  }

  void _emitEvent(String event, dynamic data) {
    if (eventEmitter != null) {
      eventEmitter!(event, data);
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'register':
      case 'runOnce':
      case 'stop':
      case 'unregister':
      case 'getTaskState':
        final taskId = args['taskId'];
        if (taskId is! String || taskId.isEmpty) {
          return ValidationResult.invalid('taskId is required');
        }
        return ValidationResult.valid();

      case 'startRepeating':
        final taskId = args['taskId'];
        if (taskId is! String || taskId.isEmpty) {
          return ValidationResult.invalid('taskId is required');
        }
        final intervalMs = args['intervalMs'];
        if (intervalMs is! num || intervalMs <= 0) {
          return ValidationResult.invalid(
            'intervalMs is required and must be a positive number',
          );
        }
        if (intervalMs < 1000) {
          return ValidationResult.invalid(
            'intervalMs must be at least 1000ms',
          );
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
