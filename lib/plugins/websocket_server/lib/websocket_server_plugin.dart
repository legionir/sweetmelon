import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef WsServerEventEmitter = Future<void> Function(
    String event, dynamic data);

class WebSocketServerPlugin extends Plugin {
  final WsServerEventEmitter? eventEmitter;

  HttpServer? _httpServer;
  final Map<String, WebSocket> _clients = {};
  int _clientCounter = 0;
  int _port = 0;

  WebSocketServerPlugin({this.eventEmitter});

  @override
  String get name => 'websocketServer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'WebSocket server for P2P communication';

  @override
  List<String> get supportedMethods => [
        'start',
        'stop',
        'sendToClient',
        'sendToAll',
        'disconnectClient',
        'getClients',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    await _stop();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'start':
        return _start(args);
      case 'stop':
        return _stop();
      case 'sendToClient':
        return _sendToClient(args);
      case 'sendToAll':
        return _sendToAll(args);
      case 'disconnectClient':
        return _disconnectClient(args);
      case 'getClients':
        return _getClients();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'running': _httpServer != null,
          'port': _port,
          'clientCount': _clients.length,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _start(Map<String, dynamic> args) async {
    if (_httpServer != null) {
      return {
        'started': true,
        'alreadyRunning': true,
        'port': _port,
        'url': 'ws://0.0.0.0:$_port',
      };
    }

    final port = (args['port'] as num?)?.toInt() ?? 0;
    final host = args['host'] as String? ?? '0.0.0.0';

    try {
      _httpServer = await HttpServer.bind(
        host == '0.0.0.0' ? InternetAddress.anyIPv4 : InternetAddress(host),
        port,
      );
      _port = _httpServer!.port;

      _httpServer!.listen((request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final ws = await WebSocketTransformer.upgrade(request);
          _handleNewClient(ws, request);
        } else {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'server': 'Sweetmelon WebSocket Server',
              'clients': _clients.length,
              'port': _port,
            }))
            ..close();
        }
      });

      BridgeLogger.info('WsServer', 'Started on port $_port');

      eventEmitter?.call('wsServer.started', {
        'port': _port,
        'host': host,
      });

      return {
        'started': true,
        'alreadyRunning': false,
        'port': _port,
        'url': 'ws://$host:$_port',
      };
    } catch (e) {
      return {'started': false, 'error': e.toString()};
    }
  }

  void _handleNewClient(WebSocket ws, HttpRequest request) {
    _clientCounter++;
    final clientId = 'client_$_clientCounter';

    _clients[clientId] = ws;

    final remoteAddress =
        request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final remotePort = request.connectionInfo?.remotePort ?? 0;

    BridgeLogger.info(
        'WsServer', 'Client connected: $clientId ($remoteAddress:$remotePort)');

    eventEmitter?.call('wsServer.clientConnected', {
      'clientId': clientId,
      'remoteAddress': remoteAddress,
      'remotePort': remotePort,
      'totalClients': _clients.length,
    });

    ws.listen(
      (data) {
        dynamic parsed;
        String dataType;

        if (data is String) {
          dataType = 'text';
          try {
            parsed = jsonDecode(data);
          } catch (_) {
            parsed = data;
          }
        } else {
          dataType = 'binary';
          parsed = base64Encode(data as List<int>);
        }

        eventEmitter?.call('wsServer.message', {
          'clientId': clientId,
          'data': parsed,
          'type': dataType,
        });
      },
      onDone: () {
        _clients.remove(clientId);
        BridgeLogger.info('WsServer', 'Client disconnected: $clientId');

        eventEmitter?.call('wsServer.clientDisconnected', {
          'clientId': clientId,
          'totalClients': _clients.length,
        });
      },
      onError: (error) {
        BridgeLogger.error('WsServer', 'Client error [$clientId]: $error');
        _clients.remove(clientId);
      },
    );
  }

  Future<Map<String, dynamic>> _stop() async {
    if (_httpServer == null) {
      return {'stopped': false, 'reason': 'not_running'};
    }

    for (final ws in _clients.values) {
      await ws.close(WebSocketStatus.goingAway, 'Server shutting down');
    }
    _clients.clear();

    await _httpServer?.close(force: true);
    _httpServer = null;

    BridgeLogger.info('WsServer', 'Stopped');

    return {'stopped': true};
  }

  Map<String, dynamic> _sendToClient(Map<String, dynamic> args) {
    final clientId = args['clientId'] as String;
    final data = args['data'];

    final ws = _clients[clientId];
    if (ws == null) {
      return {'sent': false, 'reason': 'client_not_found'};
    }

    if (data is Map || data is List) {
      ws.add(jsonEncode(data));
    } else {
      ws.add(data.toString());
    }

    return {'sent': true, 'clientId': clientId};
  }

  Map<String, dynamic> _sendToAll(Map<String, dynamic> args) {
    final data = args['data'];
    final excludeClient = args['exclude'] as String?;

    final payload =
        (data is Map || data is List) ? jsonEncode(data) : data.toString();

    int sentCount = 0;
    for (final entry in _clients.entries) {
      if (entry.key == excludeClient) continue;
      entry.value.add(payload);
      sentCount++;
    }

    return {'sent': sentCount, 'totalClients': _clients.length};
  }

  Future<Map<String, dynamic>> _disconnectClient(
      Map<String, dynamic> args) async {
    final clientId = args['clientId'] as String;
    final ws = _clients.remove(clientId);

    if (ws != null) {
      await ws.close(WebSocketStatus.normalClosure, 'Disconnected by server');
      return {'disconnected': true, 'clientId': clientId};
    }

    return {'disconnected': false, 'reason': 'not_found'};
  }

  Map<String, dynamic> _getClients() {
    return {
      'clients': _clients.keys.toList(),
      'count': _clients.length,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'sendToClient':
      case 'disconnectClient':
        if (args['clientId'] is! String) {
          return ValidationResult.invalid('clientId is required');
        }
        return ValidationResult.valid();
      case 'sendToAll':
        if (!args.containsKey('data')) {
          return ValidationResult.invalid('data is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
