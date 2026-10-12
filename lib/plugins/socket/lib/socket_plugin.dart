import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef SocketEventEmitter = Future<void> Function(String event, dynamic data);

class SocketPlugin extends Plugin {
  final SocketEventEmitter? eventEmitter;

  final Map<String, _TcpConnection> _tcpConnections = {};
  final Map<String, RawDatagramSocket> _udpSockets = {};
  ServerSocket? _tcpServer;
  StreamSubscription<Socket>? _tcpServerSub;

  SocketPlugin({this.eventEmitter});

  @override
  String get name => 'socket';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Raw TCP and UDP socket plugin';

  @override
  List<String> get supportedMethods => [
        'tcpConnect',
        'tcpSend',
        'tcpClose',
        'tcpStartServer',
        'tcpStopServer',
        'udpBind',
        'udpSend',
        'udpBroadcast',
        'udpClose',
        'getConnections',
        'closeAll',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    await _closeAll();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'tcpConnect':
        return _tcpConnect(args);
      case 'tcpSend':
        return _tcpSend(args);
      case 'tcpClose':
        return _tcpClose(args);
      case 'tcpStartServer':
        return _tcpStartServer(args);
      case 'tcpStopServer':
        return _tcpStopServer();
      case 'udpBind':
        return _udpBind(args);
      case 'udpSend':
        return _udpSend(args);
      case 'udpBroadcast':
        return _udpBroadcast(args);
      case 'udpClose':
        return _udpClose(args);
      case 'getConnections':
        return _getConnections();
      case 'closeAll':
        return _closeAll();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'tcpConnections': _tcpConnections.length,
          'udpSockets': _udpSockets.length,
          'tcpServerRunning': _tcpServer != null,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  // ── TCP Client ──

  Future<Map<String, dynamic>> _tcpConnect(Map<String, dynamic> args) async {
    final host = args['host'] as String;
    final port = (args['port'] as num).toInt();
    final id =
        args['id'] as String? ?? 'tcp_${DateTime.now().millisecondsSinceEpoch}';
    final timeoutMs = (args['timeoutMs'] as num?)?.toInt() ?? 10000;
    final encoding = args['encoding'] as String? ?? 'utf8';

    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(milliseconds: timeoutMs),
      );

      final conn = _TcpConnection(
        id: id,
        socket: socket,
        host: host,
        port: port,
      );

      conn.subscription = socket.listen(
        (data) {
          conn.receivedBytes += data.length;

          String decoded;
          if (encoding == 'base64') {
            decoded = base64Encode(data);
          } else {
            decoded = utf8.decode(data, allowMalformed: true);
          }

          eventEmitter?.call('socket.tcpData', {
            'connectionId': id,
            'data': decoded,
            'encoding': encoding,
            'bytes': data.length,
          });
        },
        onError: (error) {
          eventEmitter?.call('socket.tcpError', {
            'connectionId': id,
            'error': error.toString(),
          });
        },
        onDone: () {
          _tcpConnections.remove(id);
          eventEmitter?.call('socket.tcpClosed', {
            'connectionId': id,
          });
        },
      );

      _tcpConnections[id] = conn;

      BridgeLogger.info('Socket', 'TCP connected: $host:$port [$id]');

      return {
        'connected': true,
        'id': id,
        'host': host,
        'port': port,
        'localPort': socket.port,
      };
    } catch (e) {
      return {'connected': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _tcpSend(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final data = args['data'];
    final encoding = args['encoding'] as String? ?? 'utf8';

    final conn = _tcpConnections[id];
    if (conn == null) {
      return {'sent': false, 'reason': 'not_connected'};
    }

    try {
      if (encoding == 'base64' && data is String) {
        conn.socket.add(base64Decode(data));
      } else {
        conn.socket.write(data.toString());
      }

      conn.sentBytes += data.toString().length;

      return {'sent': true, 'id': id};
    } catch (e) {
      return {'sent': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _tcpClose(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final conn = _tcpConnections.remove(id);

    if (conn != null) {
      conn.subscription?.cancel();
      await conn.socket.close();
      return {'closed': true, 'id': id};
    }

    return {'closed': false, 'reason': 'not_found'};
  }

  // ── TCP Server ──

  Future<Map<String, dynamic>> _tcpStartServer(
      Map<String, dynamic> args) async {
    final port = (args['port'] as num?)?.toInt() ?? 0;
    final host = args['host'] as String? ?? '0.0.0.0';

    if (_tcpServer != null) {
      return {
        'started': true,
        'alreadyRunning': true,
        'port': _tcpServer!.port,
      };
    }

    try {
      _tcpServer = await ServerSocket.bind(
        host == '0.0.0.0' ? InternetAddress.anyIPv4 : InternetAddress(host),
        port,
      );

      _tcpServerSub = _tcpServer!.listen((clientSocket) {
        final clientId =
            'client_${clientSocket.remoteAddress.address}_${clientSocket.remotePort}';

        BridgeLogger.info('Socket', 'TCP client connected: $clientId');

        eventEmitter?.call('socket.tcpClientConnected', {
          'clientId': clientId,
          'remoteAddress': clientSocket.remoteAddress.address,
          'remotePort': clientSocket.remotePort,
        });

        final conn = _TcpConnection(
          id: clientId,
          socket: clientSocket,
          host: clientSocket.remoteAddress.address,
          port: clientSocket.remotePort,
        );

        conn.subscription = clientSocket.listen(
          (data) {
            eventEmitter?.call('socket.tcpServerData', {
              'clientId': clientId,
              'data': utf8.decode(data, allowMalformed: true),
              'bytes': data.length,
            });
          },
          onDone: () {
            _tcpConnections.remove(clientId);
            eventEmitter?.call('socket.tcpClientDisconnected', {
              'clientId': clientId,
            });
          },
        );

        _tcpConnections[clientId] = conn;
      });

      BridgeLogger.info(
          'Socket', 'TCP server started on port ${_tcpServer!.port}');

      return {
        'started': true,
        'alreadyRunning': false,
        'port': _tcpServer!.port,
        'host': host,
      };
    } catch (e) {
      return {'started': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _tcpStopServer() async {
    if (_tcpServer == null) {
      return {'stopped': false, 'reason': 'not_running'};
    }

    await _tcpServerSub?.cancel();
    await _tcpServer?.close();
    _tcpServer = null;

    return {'stopped': true};
  }

  // ── UDP ──

  Future<Map<String, dynamic>> _udpBind(Map<String, dynamic> args) async {
    final port = (args['port'] as num?)?.toInt() ?? 0;
    final id =
        args['id'] as String? ?? 'udp_${DateTime.now().millisecondsSinceEpoch}';
    final host = args['host'] as String? ?? '0.0.0.0';
    final broadcast = args['broadcast'] as bool? ?? false;

    try {
      final socket = await RawDatagramSocket.bind(
        host == '0.0.0.0' ? InternetAddress.anyIPv4 : InternetAddress(host),
        port,
      );

      if (broadcast) {
        socket.broadcastEnabled = true;
      }

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            eventEmitter?.call('socket.udpData', {
              'socketId': id,
              'data': utf8.decode(datagram.data, allowMalformed: true),
              'senderAddress': datagram.address.address,
              'senderPort': datagram.port,
              'bytes': datagram.data.length,
            });
          }
        }
      });

      _udpSockets[id] = socket;

      BridgeLogger.info('Socket', 'UDP bound: port ${socket.port} [$id]');

      return {
        'bound': true,
        'id': id,
        'port': socket.port,
      };
    } catch (e) {
      return {'bound': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _udpSend(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final data = args['data'] as String;
    final targetHost = args['host'] as String;
    final targetPort = (args['port'] as num).toInt();

    final socket = _udpSockets[id];
    if (socket == null) {
      return {'sent': false, 'reason': 'not_bound'};
    }

    try {
      final bytes = utf8.encode(data);
      final sent = socket.send(bytes, InternetAddress(targetHost), targetPort);

      return {'sent': true, 'bytes': sent};
    } catch (e) {
      return {'sent': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _udpBroadcast(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final data = args['data'] as String;
    final targetPort = (args['port'] as num).toInt();

    final socket = _udpSockets[id];
    if (socket == null) {
      return {'sent': false, 'reason': 'not_bound'};
    }

    try {
      socket.broadcastEnabled = true;
      final bytes = utf8.encode(data);
      final sent = socket.send(
        bytes,
        InternetAddress('255.255.255.255'),
        targetPort,
      );

      return {'sent': true, 'bytes': sent, 'broadcast': true};
    } catch (e) {
      return {'sent': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _udpClose(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final socket = _udpSockets.remove(id);

    if (socket != null) {
      socket.close();
      return {'closed': true, 'id': id};
    }

    return {'closed': false, 'reason': 'not_found'};
  }

  // ── Management ──

  Map<String, dynamic> _getConnections() {
    return {
      'tcp': _tcpConnections.values
          .map((c) => {
                'id': c.id,
                'host': c.host,
                'port': c.port,
                'sentBytes': c.sentBytes,
                'receivedBytes': c.receivedBytes,
              })
          .toList(),
      'udp': _udpSockets.entries
          .map((e) => {
                'id': e.key,
                'port': e.value.port,
              })
          .toList(),
      'tcpServer': _tcpServer != null
          ? {'port': _tcpServer!.port, 'clients': _tcpConnections.length}
          : null,
    };
  }

  Future<Map<String, dynamic>> _closeAll() async {
    final tcpCount = _tcpConnections.length;
    final udpCount = _udpSockets.length;

    for (final conn in _tcpConnections.values) {
      conn.subscription?.cancel();
      await conn.socket.close();
    }
    _tcpConnections.clear();

    for (final socket in _udpSockets.values) {
      socket.close();
    }
    _udpSockets.clear();

    await _tcpStopServer();

    return {'closedTcp': tcpCount, 'closedUdp': udpCount};
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'tcpConnect':
        if (args['host'] is! String) {
          return ValidationResult.invalid('host is required');
        }
        if (args['port'] is! num) {
          return ValidationResult.invalid('port is required');
        }
        return ValidationResult.valid();
      case 'tcpSend':
      case 'tcpClose':
        if (args['id'] is! String) {
          return ValidationResult.invalid('id is required');
        }
        return ValidationResult.valid();
      case 'udpSend':
        if (args['id'] is! String) {
          return ValidationResult.invalid('id is required');
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
      default:
        return ValidationResult.valid();
    }
  }
}

class _TcpConnection {
  final String id;
  final Socket socket;
  final String host;
  final int port;
  StreamSubscription<Uint8List>? subscription;
  int sentBytes = 0;
  int receivedBytes = 0;

  _TcpConnection({
    required this.id,
    required this.socket,
    required this.host,
    required this.port,
  });
}
