import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../utils/logger.dart';

/// پیام به worker
class WorkerMessage<T> {
  final String id;
  final String type;
  final T data;

  const WorkerMessage({
    required this.id,
    required this.type,
    required this.data,
  });
}

/// نتیجه از worker
class WorkerResult<T> {
  final String id;
  final bool success;
  final T? data;
  final String? error;

  const WorkerResult({
    required this.id,
    required this.success,
    this.data,
    this.error,
  });
}

/// تابعی که باید در isolate اجرا بشه
typedef WorkerTask<I, O> = FutureOr<O> Function(I input);

/// Pool از isolate‌ها برای کارهای سنگین
class WorkerPool {
  final int poolSize;
  final List<_Worker> _workers = [];
  bool _initialized = false;

  WorkerPool({this.poolSize = 2});

  Future<void> initialize() async {
    if (_initialized) return;

    for (int i = 0; i < poolSize; i++) {
      final worker = _Worker(id: i);
      await worker.spawn();
      _workers.add(worker);
    }

    _initialized = true;
    BridgeLogger.info('WorkerPool', 'Pool initialized with $poolSize workers');
  }

  /// اجرای یک task در isolate
  Future<R> compute<T, R>(
    R Function(T input) task,
    T input, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_initialized) await initialize();

    return Isolate.run(
      () => task(input),
      debugName: 'sweetmelon_worker',
    ).timeout(timeout);
  }

  /// اجرای JSON processing سنگین
  Future<dynamic> processJson(String jsonInput) async {
    return compute(_parseJson, jsonInput);
  }

  /// اجرای encryption سنگین
  Future<List<int>> processBytes(
    List<int> Function(List<int>) processor,
    List<int> bytes,
  ) async {
    return compute(processor, bytes);
  }

  static dynamic _parseJson(String json) {
    // heavy JSON processing
    return json.length;
  }

  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    _initialized = false;
  }

  Map<String, dynamic> get stats => {
        'poolSize': poolSize,
        'initialized': _initialized,
        'activeWorkers': _workers.where((w) => w.isActive).length,
      };
}

class _Worker {
  final int id;
  Isolate? _isolate;
  bool isActive = false;

  _Worker({required this.id});

  Future<void> spawn() async {
    isActive = true;
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    isActive = false;
  }
}

/// helper برای computations سنگین
class ComputeHelper {
  /// JSON encode سنگین در isolate
  static Future<String> encodeJsonHeavy(
    Map<String, dynamic> data,
  ) async {
    return Isolate.run(
      () => _encodeJson(data),
      debugName: 'json_encoder',
    );
  }

  /// JSON decode سنگین در isolate
  static Future<Map<String, dynamic>> decodeJsonHeavy(
    String json,
  ) async {
    return Isolate.run(
      () => _decodeJson(json),
      debugName: 'json_decoder',
    );
  }

  static String _encodeJson(Map<String, dynamic> data) {
    return jsonEncode(data);
  }

  static Map<String, dynamic> _decodeJson(String json) {
    return jsonDecode(json) as Map<String, dynamic>;
  }

  /// پردازش batch در isolate
  static Future<List<T>> processBatch<T>(
    List<T> items,
    T Function(T) processor,
  ) async {
    return Isolate.run(
      () => items.map(processor).toList(),
      debugName: 'batch_processor',
    );
  }
}
