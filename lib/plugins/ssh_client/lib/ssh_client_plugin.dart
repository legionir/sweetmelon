import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef SshEventEmitter = Future<void> Function(String event, dynamic data);

class SshClientPlugin extends Plugin {
  final SshEventEmitter? eventEmitter;

  final Map<String, SSHClient> _connections = {};

  SshClientPlugin({this.eventEmitter});

  @override
  String get name => 'sshClient';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'SSH client for remote server management';

  @override
  List<String> get supportedMethods => [
        'connect',
        'disconnect',
        'execute',
        'upload',
        'download',
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
      case 'execute':
        return _execute(args);
      case 'upload':
        return _upload(args);
      case 'download':
        return _download(args);
      case 'getConnections':
        return {
          'connections': _connections.keys.toList(),
          'count': _connections.length
        };
      case 'disconnectAll':
        return _disconnectAll();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'activeConnections': _connections.length,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _connect(Map<String, dynamic> args) async {
    final host = args['host'] as String;
    final port = (args['port'] as num?)?.toInt() ?? 22;
    final username = args['username'] as String;
    final password = args['password'] as String?;
    final privateKey = args['privateKey'] as String?;
    final id =
        args['id'] as String? ?? 'ssh_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final socket = await SSHSocket.connect(host, port);

      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password ?? '',
        identities: privateKey != null
            ? [
                ...SSHKeyPair.fromPem(privateKey),
              ]
            : null,
      );

      await client.authenticated;

      _connections[id] = client;

      BridgeLogger.info('SSH', 'Connected to $host:$port [$id]');

      return {
        'connected': true,
        'id': id,
        'host': host,
        'port': port,
      };
    } catch (e) {
      BridgeLogger.error('SSH', 'Connect failed: $e');
      return {'connected': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _disconnect(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final client = _connections.remove(id);

    if (client != null) {
      client.close();
      return {'disconnected': true, 'id': id};
    }

    return {'disconnected': false, 'reason': 'not_found'};
  }

  Future<Map<String, dynamic>> _execute(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final command = args['command'] as String;

    final client = _connections[id];
    if (client == null) {
      return {'success': false, 'reason': 'not_connected'};
    }

    try {
      final result = await client.run(command);
      final stdout = String.fromCharCodes(result);

      eventEmitter?.call('ssh.output', {
        'connectionId': id,
        'command': command,
        'output': stdout,
      });

      return {
        'success': true,
        'command': command,
        'output': stdout,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _upload(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final localPath = args['localPath'] as String;
    final remotePath = args['remotePath'] as String;

    final client = _connections[id];
    if (client == null) {
      return {'uploaded': false, 'reason': 'not_connected'};
    }

    final file = File(localPath);
    if (!await file.exists()) {
      return {'uploaded': false, 'reason': 'file_not_found'};
    }

    try {
      final sftp = await client.sftp();
      final remoteFile = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );

      final bytes = await file.readAsBytes();
      await remoteFile.write(Stream.value(bytes));
      await remoteFile.close();

      return {
        'uploaded': true,
        'localPath': localPath,
        'remotePath': remotePath,
        'size': bytes.length,
      };
    } catch (e) {
      return {'uploaded': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _download(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final remotePath = args['remotePath'] as String;
    final localPath = args['localPath'] as String;

    final client = _connections[id];
    if (client == null) {
      return {'downloaded': false, 'reason': 'not_connected'};
    }

    try {
      final sftp = await client.sftp();
      final remoteFile = await sftp.open(remotePath);
      final data = await remoteFile.readBytes();
      await remoteFile.close();

      final file = File(localPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data);

      return {
        'downloaded': true,
        'remotePath': remotePath,
        'localPath': localPath,
        'size': data.length,
      };
    } catch (e) {
      return {'downloaded': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _disconnectAll() async {
    final count = _connections.length;
    for (final client in _connections.values) {
      client.close();
    }
    _connections.clear();
    return {'disconnected': count};
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'connect':
        if (args['host'] is! String) {
          return ValidationResult.invalid('host is required');
        }
        if (args['username'] is! String) {
          return ValidationResult.invalid('username is required');
        }
        return ValidationResult.valid();
      case 'execute':
        if (args['id'] is! String) {
          return ValidationResult.invalid('id is required');
        }
        if (args['command'] is! String) {
          return ValidationResult.invalid('command is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
