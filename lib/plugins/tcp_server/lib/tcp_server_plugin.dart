import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef TcpServerEventEmitter = Future<void> Function(
    String event, dynamic data);

class TcpServerPlugin extends Plugin {
  final TcpServerEventEmitter? eventEmitter;

  final Map<String, _TcpServerInstance> _servers = {};

  TcpServerPlugin({this.eventEmitter});

  @override
  String get name => 'tcpServer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'TCP server for accepting incoming connections';

  @override
  List<String> get supportedMethods => [
        'start',
        'stop',
        'stopAll',
        'sendToClient',
        'sendToAll',
        'disconnectClient',
        'disconnectAllClients',
        'getClients',
        'getServers',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    for (final server in _servers.values) {
      await server.close();
    }
    _servers.clear();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'start':
        return _start(args);
      case 'stop':
        return _stop(args);
      case 'stopAll':
        return _stopAll();
      case 'sendToClient':
        return _sendToClient(args);
      case 'sendToAll':
        return _sendToAll(args);
      case 'disconnectClient':
        return _disconnectClient(args);
      case 'disconnectAllClients':
        return _disconnectAllClients(args);
      case 'getClients':
        return _getClients(args);
      case 'getServers':
        return _getServers();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'activeServers': _servers.length,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _start(Map<String, dynamic> args) async {
    final port = (args['port'] as num?)?.toInt() ?? 0;
    final host = args['host'] as String? ?? '0.0.0.0';
    final id = args['id'] as String? ??
        'tcp_srv_${DateTime.now().millisecondsSinceEpoch}';
    final maxClients = (args['maxClients'] as num?)?.toInt() ?? 100;
    final encoding = args['encoding'] as String? ?? 'utf8';

    if (_servers.containsKey(id)) {
      return {
        'started': true,
        'alreadyRunning': true,
        'id': id,
        'port': _servers[id]!.server.port,
      };
    }

    try {
      final server = await ServerSocket.bind(
        host == '0.0.0.0' ? InternetAddress.anyIPv4 : InternetAddress(host),
        port,
      );

      final instance = _TcpServerInstance(
        id: id,
        server: server,
        maxClients: maxClients,
        encoding: encoding,
      );

      instance.subscription = server.listen((clientSocket) {
        if (instance.clients.length >= maxClients) {
          clientSocket.close();
          BridgeLogger.warn(
              'TcpServer', '[$id] Max clients reached, rejecting');
          return;
        }

        _handleNewClient(instance, clientSocket);
      });

      _servers[id] = instance;

      BridgeLogger.info('TcpServer', '[$id] Started on port ${server.port}');

      eventEmitter?.call('tcpServer.started', {
        'serverId': id,
        'port': server.port,
        'host': host,
      });

      return {
        'started': true,
        'alreadyRunning': false,
        'id': id,
        'port': server.port,
        'host': host,
      };
    } catch (e) {
      return {'started': false, 'error': e.toString()};
    }
  }

  void _handleNewClient(_TcpServerInstance instance, Socket clientSocket) {
    instance.clientCounter++;
    final clientId = 'client_${instance.clientCounter}';

    final remoteAddress = clientSocket.remoteAddress.address;
    final remotePort = clientSocket.remotePort;

    instance.clients[clientId] = clientSocket;

    BridgeLogger.info(
      'TcpServer',
      '[${instance.id}] Client connected: $clientId ($remoteAddress:$remotePort)',
    );

    eventEmitter?.call('tcpServer.clientConnected', {
      'serverId': instance.id,
      'clientId': clientId,
      'remoteAddress': remoteAddress,
      'remotePort': remotePort,
      'totalClients': instance.clients.length,
    });

    clientSocket.listen(
      (data) {
        instance.receivedBytes += data.length;

        String decoded;
        if (instance.encoding == 'base64') {
          decoded = base64Encode(data);
        } else {
          decoded = utf8.decode(data, allowMalformed: true);
        }

        eventEmitter?.call('tcpServer.data', {
          'serverId': instance.id,
          'clientId': clientId,
          'data': decoded,
          'encoding': instance.encoding,
          'bytes': data.length,
          'remoteAddress': remoteAddress,
        });
      },
      onError: (error) {
        BridgeLogger.error('TcpServer', 'Client error [$clientId]: $error');
        instance.clients.remove(clientId);

        eventEmitter?.call('tcpServer.clientError', {
          'serverId': instance.id,
          'clientId': clientId,
          'error': error.toString(),
        });
      },
      onDone: () {
        instance.clients.remove(clientId);

        BridgeLogger.info(
            'TcpServer', '[${instance.id}] Client disconnected: $clientId');

        eventEmitter?.call('tcpServer.clientDisconnected', {
          'serverId': instance.id,
          'clientId': clientId,
          'totalClients': instance.clients.length,
        });
      },
    );
  }

  Future<Map<String, dynamic>> _stop(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final instance = _servers.remove(id);

    if (instance != null) {
      await instance.close();
      BridgeLogger.info('TcpServer', '[$id] Stopped');
      return {'stopped': true, 'id': id};
    }

    return {'stopped': false, 'reason': 'not_found'};
  }

  Future<Map<String, dynamic>> _stopAll() async {
    final count = _servers.length;
    for (final instance in _servers.values) {
      await instance.close();
    }
    _servers.clear();
    return {'stopped': count};
  }

  Map<String, dynamic> _sendToClient(Map<String, dynamic> args) {
    final serverId = args['serverId'] as String;
    final clientId = args['clientId'] as String;
    final data = args['data'];
    final encoding = args['encoding'] as String? ?? 'utf8';

    final instance = _servers[serverId];
    if (instance == null) return {'sent': false, 'reason': 'server_not_found'};

    final client = instance.clients[clientId];
    if (client == null) return {'sent': false, 'reason': 'client_not_found'};

    try {
      if (encoding == 'base64' && data is String) {
        client.add(base64Decode(data));
      } else {
        client.write(data.toString());
      }

      instance.sentBytes += data.toString().length;
      return {'sent': true, 'clientId': clientId};
    } catch (e) {
      return {'sent': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _sendToAll(Map<String, dynamic> args) {
    final serverId = args['serverId'] as String;
    final data = args['data'];
    final excludeClient = args['exclude'] as String?;

    final instance = _servers[serverId];
    if (instance == null) return {'sent': 0, 'reason': 'server_not_found'};

    int sentCount = 0;
    final payload = data.toString();

    for (final entry in instance.clients.entries) {
      if (entry.key == excludeClient) continue;
      try {
        entry.value.write(payload);
        sentCount++;
      } catch (_) {}
    }

    return {'sent': sentCount, 'totalClients': instance.clients.length};
  }

  Future<Map<String, dynamic>> _disconnectClient(
      Map<String, dynamic> args) async {
    final serverId = args['serverId'] as String;
    final clientId = args['clientId'] as String;

    final instance = _servers[serverId];
    if (instance == null) {
      return {'disconnected': false, 'reason': 'server_not_found'};
    }

    final client = instance.clients.remove(clientId);
    if (client != null) {
      await client.close();
      return {'disconnected': true, 'clientId': clientId};
    }

    return {'disconnected': false, 'reason': 'client_not_found'};
  }

  Future<Map<String, dynamic>> _disconnectAllClients(
      Map<String, dynamic> args) async {
    final serverId = args['serverId'] as String;
    final instance = _servers[serverId];
    if (instance == null) return {'disconnected': 0};

    final count = instance.clients.length;
    for (final client in instance.clients.values) {
      await client.close();
    }
    instance.clients.clear();

    return {'disconnected': count};
  }

  Map<String, dynamic> _getClients(Map<String, dynamic> args) {
    final serverId = args['serverId'] as String;
    final instance = _servers[serverId];

    if (instance == null) return {'clients': <dynamic>[], 'count': 0};

    return {
      'clients': instance.clients.entries.map((e) {
        return {
          'clientId': e.key,
          'remoteAddress': e.value.remoteAddress.address,
          'remotePort': e.value.remotePort,
        };
      }).toList(),
      'count': instance.clients.length,
    };
  }

  Map<String, dynamic> _getServers() {
    return {
      'servers': _servers.values.map((s) {
        return {
          'id': s.id,
          'port': s.server.port,
          'clients': s.clients.length,
          'maxClients': s.maxClients,
          'sentBytes': s.sentBytes,
          'receivedBytes': s.receivedBytes,
        };
      }).toList(),
      'count': _servers.length,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'stop':
        if (args['id'] is! String) {
          return ValidationResult.invalid('id is required');
        }
        return ValidationResult.valid();
      case 'sendToClient':
      case 'disconnectClient':
        if (args['serverId'] is! String) {
          return ValidationResult.invalid('serverId is required');
        }
        if (args['clientId'] is! String) {
          return ValidationResult.invalid('clientId is required');
        }
        return ValidationResult.valid();
      case 'sendToAll':
      case 'getClients':
      case 'disconnectAllClients':
        if (args['serverId'] is! String) {
          return ValidationResult.invalid('serverId is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}

class _TcpServerInstance {
  final String id;
  final ServerSocket server;
  final int maxClients;
  final String encoding;
  final Map<String, Socket> clients = {};
  StreamSubscription<Socket>? subscription;
  int clientCounter = 0;
  int sentBytes = 0;
  int receivedBytes = 0;

  _TcpServerInstance({
    required this.id,
    required this.server,
    this.maxClients = 100,
    this.encoding = 'utf8',
  });

  Future<void> close() async {
    subscription?.cancel();
    for (final client in clients.values) {
      await client.close();
    }
    clients.clear();
    await server.close();
  }
}
