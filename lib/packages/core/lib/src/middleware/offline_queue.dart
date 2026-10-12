import 'dart:async';
import 'dart:collection';

import '../protocol/message_protocol.dart';
import '../utils/logger.dart';

enum QueueItemStatus {
  pending,
  processing,
  completed,
  failed,
  expired,
}

class QueueItem {
  final String id;
  final PluginRequest request;
  final DateTime createdAt;
  final DateTime? expiresAt;
  QueueItemStatus status;
  int attempts;
  String? lastError;

  QueueItem({
    required this.id,
    required this.request,
    required this.createdAt,
    this.expiresAt,
    this.status = QueueItemStatus.pending,
    this.attempts = 0,
    this.lastError,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plugin': request.plugin,
        'method': request.method,
        'status': status.name,
        'attempts': attempts,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'lastError': lastError,
      };
}

typedef QueueExecutor = Future<PluginResponse> Function(PluginRequest request);
typedef QueueEventCallback = void Function(String event, dynamic data);

class OfflineQueueConfig {
  final int maxQueueSize;
  final Duration defaultTtl;
  final Duration processInterval;
  final int maxRetries;
  final bool persistQueue;

  const OfflineQueueConfig({
    this.maxQueueSize = 200,
    this.defaultTtl = const Duration(hours: 1),
    this.processInterval = const Duration(seconds: 5),
    this.maxRetries = 3,
    this.persistQueue = false,
  });
}

class OfflineQueue {
  final OfflineQueueConfig config;
  final QueueExecutor executor;
  final QueueEventCallback? onEvent;

  final Queue<QueueItem> _queue = Queue<QueueItem>();
  final List<QueueItem> _completed = [];
  final List<QueueItem> _failed = [];

  Timer? _processTimer;
  bool _processing = false;
  bool _online = true;
  bool _paused = false;

  OfflineQueue({
    required this.executor,
    this.config = const OfflineQueueConfig(),
    this.onEvent,
  });

  /// آیا آنلاین هستیم
  bool get isOnline => _online;

  /// ست کردن وضعیت آنلاین
  void setOnline(bool online) {
    final wasOffline = !_online;
    _online = online;

    BridgeLogger.info(
      'OfflineQueue',
      'Connection status: ${online ? "ONLINE" : "OFFLINE"}',
    );

    if (online && wasOffline && _queue.isNotEmpty) {
      BridgeLogger.info(
        'OfflineQueue',
        'Back online — processing ${_queue.length} queued items',
      );
      _emitEvent('queue.online', {
        'pendingCount': _queue.length,
      });
      _processQueue();
    }

    if (!online) {
      _emitEvent('queue.offline', {
        'pendingCount': _queue.length,
      });
    }
  }

  /// اضافه کردن به صف
  String enqueue(PluginRequest request, {Duration? ttl}) {
    if (_queue.length >= config.maxQueueSize) {
      // حذف قدیمی‌ترین
      final removed = _queue.removeFirst();
      BridgeLogger.warn(
        'OfflineQueue',
        'Queue full, removing oldest: ${removed.request.plugin}.${removed.request.method}',
      );
    }

    final item = QueueItem(
      id: 'q_${DateTime.now().millisecondsSinceEpoch}_${_queue.length}',
      request: request,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(ttl ?? config.defaultTtl),
    );

    _queue.add(item);

    BridgeLogger.info(
      'OfflineQueue',
      'Enqueued: ${request.plugin}.${request.method} [${item.id}] '
          '(queue size: ${_queue.length})',
    );

    _emitEvent('queue.enqueued', item.toJson());

    // اگه آنلاینیم، فورا process کن
    if (_online && !_paused) {
      _processQueue();
    }

    return item.id;
  }

  /// شروع processing timer
  void start() {
    _processTimer?.cancel();
    _processTimer = Timer.periodic(
      config.processInterval,
      (_) {
        if (_online && !_paused && _queue.isNotEmpty) {
          _processQueue();
        }
      },
    );
  }

  /// توقف
  void pause() {
    _paused = true;
  }

  /// ادامه
  void resume() {
    _paused = false;
    if (_online && _queue.isNotEmpty) {
      _processQueue();
    }
  }

  /// پردازش صف
  Future<void> _processQueue() async {
    if (_processing || _paused) return;
    _processing = true;

    try {
      while (_queue.isNotEmpty && _online && !_paused) {
        final item = _queue.first;

        // بررسی انقضا
        if (item.isExpired) {
          _queue.removeFirst();
          item.status = QueueItemStatus.expired;
          _failed.add(item);

          BridgeLogger.warn(
            'OfflineQueue',
            'Expired: ${item.request.plugin}.${item.request.method} [${item.id}]',
          );

          _emitEvent('queue.expired', item.toJson());
          continue;
        }

        // پردازش
        item.status = QueueItemStatus.processing;
        item.attempts++;

        try {
          final response = await executor(item.request);

          if (response.success) {
            _queue.removeFirst();
            item.status = QueueItemStatus.completed;
            _completed.add(item);

            _emitEvent('queue.completed', {
              ...item.toJson(),
              'response': response.toJson(),
            });
          } else {
            _handleItemFailure(
                item, response.error?.message ?? 'Unknown error');
          }
        } catch (e) {
          _handleItemFailure(item, e.toString());
        }
      }
    } finally {
      _processing = false;
    }
  }

  void _handleItemFailure(QueueItem item, String error) {
    item.lastError = error;

    if (item.attempts >= config.maxRetries) {
      _queue.removeFirst();
      item.status = QueueItemStatus.failed;
      _failed.add(item);

      BridgeLogger.error(
        'OfflineQueue',
        'Failed permanently: ${item.request.plugin}.${item.request.method} '
            'after ${item.attempts} attempts: $error',
      );

      _emitEvent('queue.failed', item.toJson());
    } else {
      item.status = QueueItemStatus.pending;
      // move to back of queue
      _queue.removeFirst();
      _queue.add(item);

      BridgeLogger.warn(
        'OfflineQueue',
        'Retrying later: ${item.request.plugin}.${item.request.method} '
            '(attempt ${item.attempts}/${config.maxRetries})',
      );
    }
  }

  void _emitEvent(String event, dynamic data) {
    onEvent?.call(event, data);
  }

  /// خالی کردن صف
  void clear() {
    _queue.clear();
    _completed.clear();
    _failed.clear();
  }

  /// حذف یک آیتم
  bool remove(String itemId) {
    final before = _queue.length;
    _queue.removeWhere((item) => item.id == itemId);
    return _queue.length < before;
  }

  /// وضعیت
  Map<String, dynamic> get stats => {
        'pending': _queue.length,
        'completed': _completed.length,
        'failed': _failed.length,
        'online': _online,
        'paused': _paused,
        'processing': _processing,
        'maxQueueSize': config.maxQueueSize,
      };

  /// لیست آیتم‌های pending
  List<Map<String, dynamic>> get pendingItems =>
      _queue.map((i) => i.toJson()).toList();

  void dispose() {
    _processTimer?.cancel();
    _queue.clear();
  }
}
