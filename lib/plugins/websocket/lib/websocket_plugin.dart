import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef WsEventEmitter = Future<void> Function(String event, dynamic data);

class WebSocketPlugin extends Plugin {
  final WsEventEmitter? eventEmitter;

  final Map<String, _ManagedSocket> _sockets = {};

  WebSocketPlugin({this.eventEmitter});

  @override
  String get name => 'websocket';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'WebSocket real-time communication plugin';

  @override
  List<String> get supportedMethods => [
        'connect',
        'disconnect',
        'send',
        'sendJson',
        'getState',
        'getConnections',
        'disconnectAll',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    await _disconnectAll();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'connect':
        return _connect(args);
      case 'disconnect':
        return _disconnect(args);
      case 'send':
        return _send(args);
      case 'sendJson':
        return _sendJson(args);
      case 'getState':
        return _getState(args);
      case 'getConnections':
        return _getConnections();
      case 'disconnectAll':
        return _disconnectAll();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'activeConnections': _sockets.length,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _connect(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    final id =
        args['id'] as String? ?? 'ws_${DateTime.now().millisecondsSinceEpoch}';
    final protocols = args['protocols'] != null
        ? List<String>.from(args['protocols'] as List)
        : <String>[];
    final headers = _parseHeaders(args['headers']);
    final pingIntervalMs = (args['pingIntervalMs'] as num?)?.toInt();
    final autoReconnect = args['autoReconnect'] as bool? ?? false;
    final maxReconnectAttempts =
        (args['maxReconnectAttempts'] as num?)?.toInt() ?? 5;
    final reconnectDelayMs =
        (args['reconnectDelayMs'] as num?)?.toInt() ?? 3000;

    if (_sockets.containsKey(id)) {
      final existing = _sockets[id]!;
      if (existing.isConnected) {
        return {
          'id': id,
          'connected': true,
          'alreadyConnected': true,
          'url': url,
        };
      }
      await existing.close();
      _sockets.remove(id);
    }

    BridgeLogger.info('WebSocket', 'Connecting: $url [id=$id]');

    try {
      final ws = await WebSocket.connect(
        url,
        protocols: protocols.isNotEmpty ? protocols : null,
        headers: headers.isNotEmpty ? headers : null,
      );

      if (pingIntervalMs != null) {
        ws.pingInterval = Duration(milliseconds: pingIntervalMs);
      }

      final managed = _ManagedSocket(
        id: id,
        url: url,
        socket: ws,
        autoReconnect: autoReconnect,
        maxReconnectAttempts: maxReconnectAttempts,
        reconnectDelayMs: reconnectDelayMs,
      );

      _sockets[id] = managed;

      _listenToSocket(managed);

      _emitEvent('websocket.connected', {
        'id': id,
        'url': url,
        'timestamp': DateTime.now().toIso8601String(),
      });

      BridgeLogger.info('WebSocket', 'Connected: $url [id=$id]');

      return {
        'id': id,
        'connected': true,
        'alreadyConnected': false,
        'url': url,
      };
    } catch (e) {
      BridgeLogger.error('WebSocket', 'Connect failed: $e');

      _emitEvent('websocket.error', {
        'id': id,
        'url': url,
        'error': e.toString(),
        'type': 'connect_failed',
      });

      return {
        'id': id,
        'connected': false,
        'error': e.toString(),
      };
    }
  }

  void _listenToSocket(_ManagedSocket managed) {
    managed.subscription = managed.socket.listen(
      (data) {
        managed.messageCount++;

        dynamic parsedData;
        String dataType;

        if (data is String) {
          dataType = 'text';
          try {
            parsedData = jsonDecode(data);
          } catch (_) {
            parsedData = data;
          }
        } else {
          dataType = 'binary';
          parsedData = base64Encode(data as List<int>);
        }

        _emitEvent('websocket.message', {
          'id': managed.id,
          'data': parsedData,
          'type': dataType,
          'messageNumber': managed.messageCount,
          'timestamp': DateTime.now().toIso8601String(),
        });
      },
      onError: (error) {
        BridgeLogger.error(
          'WebSocket',
          '[${managed.id}] Error: $error',
        );

        _emitEvent('websocket.error', {
          'id': managed.id,
          'error': error.toString(),
          'type': 'stream_error',
        });
      },
      onDone: () {
        final closeCode = managed.socket.closeCode;
        final closeReason = managed.socket.closeReason;

        BridgeLogger.info(
          'WebSocket',
          '[${managed.id}] Disconnected: $closeCode $closeReason',
        );

        _emitEvent('websocket.disconnected', {
          'id': managed.id,
          'closeCode': closeCode,
          'closeReason': closeReason,
          'timestamp': DateTime.now().toIso8601String(),
        });

        _sockets.remove(managed.id);

        // Auto-reconnect
        if (managed.autoReconnect &&
            managed.reconnectAttempts < managed.maxReconnectAttempts) {
          _scheduleReconnect(managed);
        }
      },
      cancelOnError: false,
    );
  }

  void _scheduleReconnect(_ManagedSocket managed) {
    managed.reconnectAttempts++;

    final delay = managed.reconnectDelayMs * managed.reconnectAttempts;

    BridgeLogger.info(
      'WebSocket',
      '[${managed.id}] Reconnecting in ${delay}ms '
          '(attempt ${managed.reconnectAttempts}/${managed.maxReconnectAttempts})',
    );

    _emitEvent('websocket.reconnecting', {
      'id': managed.id,
      'attempt': managed.reconnectAttempts,
      'maxAttempts': managed.maxReconnectAttempts,
      'delayMs': delay,
    });

    Timer(Duration(milliseconds: delay), () {
      if (!_sockets.containsKey(managed.id)) {
        _connect({
          'url': managed.url,
          'id': managed.id,
          'autoReconnect': managed.autoReconnect,
          'maxReconnectAttempts': managed.maxReconnectAttempts,
          'reconnectDelayMs': managed.reconnectDelayMs,
        });
      }
    });
  }

  Future<Map<String, dynamic>> _disconnect(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final code =
        (args['code'] as num?)?.toInt() ?? WebSocketStatus.normalClosure;
    final reason = args['reason'] as String? ?? '';

    final managed = _sockets[id];
    if (managed == null) {
      return {'id': id, 'disconnected': false, 'reason': 'not_found'};
    }

    managed.autoReconnect = false;
    await managed.close(code, reason);
    _sockets.remove(id);

    return {'id': id, 'disconnected': true};
  }

  Future<Map<String, dynamic>> _send(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final data = args['data'];

    final managed = _sockets[id];
    if (managed == null || !managed.isConnected) {
      return {'id': id, 'sent': false, 'reason': 'not_connected'};
    }

    if (data is String) {
      managed.socket.add(data);
    } else if (data is List) {
      managed.socket.add(data);
    } else {
      managed.socket.add(data.toString());
    }

    managed.sentCount++;

    return {'id': id, 'sent': true, 'sentCount': managed.sentCount};
  }

  Future<Map<String, dynamic>> _sendJson(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final data = args['data'];

    final managed = _sockets[id];
    if (managed == null || !managed.isConnected) {
      return {'id': id, 'sent': false, 'reason': 'not_connected'};
    }

    final jsonStr = jsonEncode(data);
    managed.socket.add(jsonStr);
    managed.sentCount++;

    return {'id': id, 'sent': true, 'sentCount': managed.sentCount};
  }

  Map<String, dynamic> _getState(Map<String, dynamic> args) {
    final id = args['id'] as String;
    final managed = _sockets[id];

    if (managed == null) {
      return {'id': id, 'exists': false};
    }

    return {
      'id': id,
      'exists': true,
      'connected': managed.isConnected,
      'url': managed.url,
      'messageCount': managed.messageCount,
      'sentCount': managed.sentCount,
      'reconnectAttempts': managed.reconnectAttempts,
      'closeCode': managed.socket.closeCode,
    };
  }

  Map<String, dynamic> _getConnections() {
    return {
      'connections': _sockets.values
          .map((m) => {
                'id': m.id,
                'url': m.url,
                'connected': m.isConnected,
                'messageCount': m.messageCount,
                'sentCount': m.sentCount,
              })
          .toList(),
      'count': _sockets.length,
    };
  }

  Future<Map<String, dynamic>> _disconnectAll() async {
    final count = _sockets.length;

    for (final managed in _sockets.values.toList()) {
      managed.autoReconnect = false;
      await managed.close();
    }
    _sockets.clear();

    return {'disconnected': count};
  }

  Map<String, String> _parseHeaders(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
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
      case 'connect':
        final url = args['url'];
        if (url is! String || url.isEmpty) {
          return ValidationResult.invalid('url is required');
        }
        if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
          return ValidationResult.invalid(
            'url must start with ws:// or wss://',
          );
        }
        return ValidationResult.valid();

      case 'disconnect':
      case 'getState':
        final id = args['id'];
        if (id is! String || id.isEmpty) {
          return ValidationResult.invalid('id is required');
        }
        return ValidationResult.valid();

      case 'send':
      case 'sendJson':
        final id = args['id'];
        if (id is! String || id.isEmpty) {
          return ValidationResult.invalid('id is required');
        }
        if (!args.containsKey('data')) {
          return ValidationResult.invalid('data is required');
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}

class _ManagedSocket {
  final String id;
  final String url;
  final WebSocket socket;
  bool autoReconnect;
  final int maxReconnectAttempts;
  final int reconnectDelayMs;

  StreamSubscription<dynamic>? subscription;
  int messageCount = 0;
  int sentCount = 0;
  int reconnectAttempts = 0;

  _ManagedSocket({
    required this.id,
    required this.url,
    required this.socket,
    this.autoReconnect = false,
    this.maxReconnectAttempts = 5,
    this.reconnectDelayMs = 3000,
  });

  bool get isConnected => socket.readyState == WebSocket.open;

  Future<void> close([int? code, String? reason]) async {
    subscription?.cancel();
    try {
      await socket.close(
        code ?? WebSocketStatus.normalClosure,
        reason ?? '',
      );
    } catch (_) {}
  }
}
