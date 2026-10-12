import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef UdpServerEventEmitter = Future<void> Function(
    String event, dynamic data);

class UdpServerPlugin extends Plugin {
  final UdpServerEventEmitter? eventEmitter;

  final Map<String, _UdpServerInstance> _servers = {};

  UdpServerPlugin({this.eventEmitter});

  @override
  String get name => 'udpServer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'UDP server for receiving datagrams';

  @override
  List<String> get supportedMethods => [
        'start',
        'stop',
        'stopAll',
        'sendTo',
        'broadcast',
        'getServers',
        'getStats',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    for (final server in _servers.values) {
      server.close();
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
      case 'sendTo':
        return _sendTo(args);
      case 'broadcast':
        return _broadcast(args);
      case 'getServers':
        return _getServers();
      case 'getStats':
        return _getStats(args);
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
        'udp_srv_${DateTime.now().millisecondsSinceEpoch}';
    final enableBroadcast = args['broadcast'] as bool? ?? true;
    final encoding = args['encoding'] as String? ?? 'utf8';

    if (_servers.containsKey(id)) {
      return {
        'started': true,
        'alreadyRunning': true,
        'id': id,
        'port': _servers[id]!.socket.port,
      };
    }

    try {
      final socket = await RawDatagramSocket.bind(
        host == '0.0.0.0' ? InternetAddress.anyIPv4 : InternetAddress(host),
        port,
      );

      if (enableBroadcast) {
        socket.broadcastEnabled = true;
      }

      final instance = _UdpServerInstance(
        id: id,
        socket: socket,
        encoding: encoding,
      );

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            instance.packetCount++;
            instance.receivedBytes += datagram.data.length;

            String decoded;
            if (encoding == 'base64') {
              decoded = base64Encode(datagram.data);
            } else {
              decoded = utf8.decode(datagram.data, allowMalformed: true);
            }

            // Track unique senders
            final senderId = '${datagram.address.address}:${datagram.port}';
            instance.knownSenders.add(senderId);

            eventEmitter?.call('udpServer.data', {
              'serverId': id,
              'data': decoded,
              'encoding': encoding,
              'senderAddress': datagram.address.address,
              'senderPort': datagram.port,
              'bytes': datagram.data.length,
              'packetNumber': instance.packetCount,
            });
          }
        }
      });

      _servers[id] = instance;

      BridgeLogger.info('UdpServer', '[$id] Started on port ${socket.port}');

      eventEmitter?.call('udpServer.started', {
        'serverId': id,
        'port': socket.port,
        'host': host,
        'broadcast': enableBroadcast,
      });

      return {
        'started': true,
        'alreadyRunning': false,
        'id': id,
        'port': socket.port,
        'host': host,
      };
    } catch (e) {
      return {'started': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _sendTo(Map<String, dynamic> args) {
    final serverId = args['serverId'] as String;
    final data = args['data'] as String;
    final targetHost = args['host'] as String;
    final targetPort = (args['port'] as num).toInt();
    final encoding = args['encoding'] as String? ?? 'utf8';

    final instance = _servers[serverId];
    if (instance == null) return {'sent': false, 'reason': 'server_not_found'};

    try {
      List<int> bytes;
      if (encoding == 'base64') {
        bytes = base64Decode(data);
      } else {
        bytes = utf8.encode(data);
      }

      final sent =
          instance.socket.send(bytes, InternetAddress(targetHost), targetPort);
      instance.sentBytes += sent;

      return {'sent': true, 'bytes': sent};
    } catch (e) {
      return {'sent': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _broadcast(Map<String, dynamic> args) {
    final serverId = args['serverId'] as String;
    final data = args['data'] as String;
    final targetPort = (args['port'] as num).toInt();

    final instance = _servers[serverId];
    if (instance == null) return {'sent': false, 'reason': 'server_not_found'};

    try {
      instance.socket.broadcastEnabled = true;
      final bytes = utf8.encode(data);
      final sent = instance.socket.send(
        bytes,
        InternetAddress('255.255.255.255'),
        targetPort,
      );

      instance.sentBytes += sent;
      return {'sent': true, 'bytes': sent, 'broadcast': true};
    } catch (e) {
      return {'sent': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _stop(Map<String, dynamic> args) {
    final id = args['id'] as String;
    final instance = _servers.remove(id);

    if (instance != null) {
      instance.close();
      BridgeLogger.info('UdpServer', '[$id] Stopped');
      return {'stopped': true, 'id': id};
    }

    return {'stopped': false, 'reason': 'not_found'};
  }

  Map<String, dynamic> _stopAll() {
    final count = _servers.length;
    for (final instance in _servers.values) {
      instance.close();
    }
    _servers.clear();
    return {'stopped': count};
  }

  Map<String, dynamic> _getServers() {
    return {
      'servers': _servers.values.map((s) => s.toJson()).toList(),
      'count': _servers.length,
    };
  }

  Map<String, dynamic> _getStats(Map<String, dynamic> args) {
    final serverId = args['serverId'] as String;
    final instance = _servers[serverId];

    if (instance == null) return {'found': false};

    return {'found': true, ...instance.toJson()};
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'stop':
      case 'getStats':
        if (args['id'] is! String && args['serverId'] is! String) {
          return ValidationResult.invalid('id or serverId is required');
        }
        return ValidationResult.valid();
      case 'sendTo':
        if (args['serverId'] is! String) {
          return ValidationResult.invalid('serverId is required');
        }
        if (args['host'] is! String) {
          return ValidationResult.invalid('host is required');
        }
        if (args['port'] is! num) {
          return ValidationResult.invalid('port is required');
        }
        if (args['data'] is! String) {
          return ValidationResult.invalid('data is required');
        }
        return ValidationResult.valid();
      case 'broadcast':
        if (args['serverId'] is! String) {
          return ValidationResult.invalid('serverId is required');
        }
        if (args['port'] is! num) {
          return ValidationResult.invalid('port is required');
        }
        if (args['data'] is! String) {
          return ValidationResult.invalid('data is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}

class _UdpServerInstance {
  final String id;
  final RawDatagramSocket socket;
  final String encoding;
  int packetCount = 0;
  int receivedBytes = 0;
  int sentBytes = 0;
  final Set<String> knownSenders = {};

  _UdpServerInstance({
    required this.id,
    required this.socket,
    this.encoding = 'utf8',
  });

  void close() {
    socket.close();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'port': socket.port,
        'packetCount': packetCount,
        'receivedBytes': receivedBytes,
        'sentBytes': sentBytes,
        'uniqueSenders': knownSenders.length,
        'senders': knownSenders.toList(),
      };
}
