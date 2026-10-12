import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef SshServerEventEmitter = Future<void> Function(
    String event, dynamic data);

/// SSH Server ساده‌شده — اجرای command روی دستگاه
/// توجه: این یک SSH server واقعی نیست (نیاز به crypto handshake داره)
/// بلکه یک TCP command server هست که ساختار مشابه SSH داره
class SshServerPlugin extends Plugin {
  final SshServerEventEmitter? eventEmitter;

  ServerSocket? _server;
  int _port = 0;
  bool _running = false;
  final Map<String, _SshSession> _sessions = {};
  int _sessionCounter = 0;

  String _username = 'admin';
  String _password = 'admin';
  final Set<String> _allowedCommands = {};
  final Set<String> _blockedCommands = {'rm -rf', 'format', 'mkfs', 'dd'};
  bool _allowAllCommands = false;

  SshServerPlugin({this.eventEmitter});

  @override
  String get name => 'sshServer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Command server with SSH-like interface';

  @override
  List<String> get supportedMethods => [
        'start',
        'stop',
        'configure',
        'addAllowedCommand',
        'addBlockedCommand',
        'getClients',
        'disconnectClient',
        'getCommandLog',
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
      case 'configure':
        return _configure(args);
      case 'addAllowedCommand':
        return _addAllowedCommand(args);
      case 'addBlockedCommand':
        return _addBlockedCommand(args);
      case 'getClients':
        return _getClients();
      case 'disconnectClient':
        return _disconnectClient(args);
      case 'getCommandLog':
        return _getCommandLog(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'running': _running,
          'port': _port,
          'clients': _sessions.length,
          'allowAllCommands': _allowAllCommands,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _configure(Map<String, dynamic> args) {
    _username = args['username'] as String? ?? _username;
    _password = args['password'] as String? ?? _password;
    _allowAllCommands = args['allowAllCommands'] as bool? ?? false;

    if (args['allowedCommands'] is List) {
      _allowedCommands.addAll(
        List<String>.from(args['allowedCommands'] as List),
      );
    }

    return {
      'configured': true,
      'username': _username,
      'allowAllCommands': _allowAllCommands,
      'allowedCommands': _allowedCommands.toList(),
      'blockedCommands': _blockedCommands.toList(),
    };
  }

  Map<String, dynamic> _addAllowedCommand(Map<String, dynamic> args) {
    final command = args['command'] as String;
    _allowedCommands.add(command);
    return {'added': true, 'command': command};
  }

  Map<String, dynamic> _addBlockedCommand(Map<String, dynamic> args) {
    final command = args['command'] as String;
    _blockedCommands.add(command);
    return {'added': true, 'command': command};
  }

  Future<Map<String, dynamic>> _start(Map<String, dynamic> args) async {
    if (_running) {
      return {'started': true, 'alreadyRunning': true, 'port': _port};
    }

    final port = (args['port'] as num?)?.toInt() ?? 2222;
    final host = args['host'] as String? ?? '0.0.0.0';

    try {
      _server = await ServerSocket.bind(
        host == '0.0.0.0' ? InternetAddress.anyIPv4 : InternetAddress(host),
        port,
      );

      _port = _server!.port;
      _running = true;

      _server!.listen(_handleNewConnection);

      BridgeLogger.info('SshServer', 'Started on port $_port');

      eventEmitter?.call('sshServer.started', {
        'port': _port,
        'host': host,
      });

      return {
        'started': true,
        'alreadyRunning': false,
        'port': _port,
      };
    } catch (e) {
      return {'started': false, 'error': e.toString()};
    }
  }

  void _handleNewConnection(Socket client) {
    _sessionCounter++;
    final sessionId = 'ssh_$_sessionCounter';

    final session = _SshSession(
      id: sessionId,
      socket: client,
      remoteAddress: client.remoteAddress.address,
    );

    _sessions[sessionId] = session;

    BridgeLogger.info('SshServer', 'Client connected: $sessionId');

    eventEmitter?.call('sshServer.clientConnected', {
      'sessionId': sessionId,
      'remoteAddress': client.remoteAddress.address,
    });

    client.write('Sweetmelon Command Server\r\n');
    client.write('Username: ');

    client.listen(
      (data) async {
        final input = utf8.decode(data).trim();

        if (!session.authenticated) {
          if (session.username == null) {
            session.username = input;
            client.write('Password: ');
          } else {
            if (session.username == _username && input == _password) {
              session.authenticated = true;
              client.write('Welcome! Type commands or "exit" to quit.\r\n');
              client.write('> ');
            } else {
              client.write('Authentication failed.\r\n');
              await client.close();
              _sessions.remove(sessionId);
            }
          }
          return;
        }

        // Authenticated — handle command
        if (input == 'exit' || input == 'quit') {
          client.write('Goodbye.\r\n');
          await client.close();
          _sessions.remove(sessionId);
          return;
        }

        await _executeCommand(session, input);
      },
      onDone: () {
        _sessions.remove(sessionId);
        eventEmitter?.call('sshServer.clientDisconnected', {
          'sessionId': sessionId,
        });
      },
    );
  }

  Future<void> _executeCommand(_SshSession session, String command) async {
    // Security check
    for (final blocked in _blockedCommands) {
      if (command.toLowerCase().contains(blocked.toLowerCase())) {
        session.socket.write('ERROR: Command blocked for security.\r\n> ');
        session.commandLog.add(_CommandEntry(
          command: command,
          output: 'BLOCKED',
          exitCode: -1,
        ));
        return;
      }
    }

    if (!_allowAllCommands && _allowedCommands.isNotEmpty) {
      final cmdBase = command.split(' ').first;
      if (!_allowedCommands.contains(cmdBase)) {
        session.socket
            .write('ERROR: Command "$cmdBase" not in whitelist.\r\n> ');
        return;
      }
    }

    BridgeLogger.info('SshServer', '[${session.id}] Executing: $command');

    eventEmitter?.call('sshServer.command', {
      'sessionId': session.id,
      'command': command,
    });

    try {
      final parts = command.split(' ');
      final executable = parts[0];
      final arguments = parts.length > 1 ? parts.sublist(1) : <String>[];

      final result = await Process.run(
        executable,
        arguments,
        runInShell: true,
      ).timeout(const Duration(seconds: 30));

      final output = result.stdout.toString();
      final error = result.stderr.toString();

      session.commandLog.add(_CommandEntry(
        command: command,
        output: output + error,
        exitCode: result.exitCode,
      ));

      if (output.isNotEmpty) session.socket.write(output);
      if (error.isNotEmpty) session.socket.write(error);
      if (!output.endsWith('\n') && !error.endsWith('\n')) {
        session.socket.write('\r\n');
      }

      session.socket.write('> ');

      eventEmitter?.call('sshServer.commandResult', {
        'sessionId': session.id,
        'command': command,
        'exitCode': result.exitCode,
        'outputLength': output.length + error.length,
      });
    } catch (e) {
      session.socket.write('ERROR: ${e.toString()}\r\n> ');

      session.commandLog.add(_CommandEntry(
        command: command,
        output: 'ERROR: $e',
        exitCode: -1,
      ));
    }
  }

  Future<Map<String, dynamic>> _stop() async {
    if (!_running) return {'stopped': false};

    for (final session in _sessions.values) {
      session.socket.write('Server shutting down.\r\n');
      await session.socket.close();
    }
    _sessions.clear();

    await _server?.close();
    _server = null;
    _running = false;

    return {'stopped': true};
  }

  Map<String, dynamic> _getClients() {
    return {
      'clients': _sessions.values.map((s) => s.toJson()).toList(),
      'count': _sessions.length,
    };
  }

  Future<Map<String, dynamic>> _disconnectClient(
      Map<String, dynamic> args) async {
    final sessionId = args['sessionId'] as String;
    final session = _sessions.remove(sessionId);

    if (session != null) {
      session.socket.write('Disconnected by server.\r\n');
      await session.socket.close();
      return {'disconnected': true};
    }

    return {'disconnected': false};
  }

  Map<String, dynamic> _getCommandLog(Map<String, dynamic> args) {
    final sessionId = args['sessionId'] as String;
    final session = _sessions[sessionId];

    if (session == null) return {'log': <dynamic>[], 'found': false};

    return {
      'found': true,
      'log': session.commandLog.map((e) => e.toJson()).toList(),
      'count': session.commandLog.length,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'start':
        return ValidationResult.valid();
      case 'disconnectClient':
      case 'getCommandLog':
        if (args['sessionId'] is! String) {
          return ValidationResult.invalid('sessionId is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}

class _SshSession {
  final String id;
  final Socket socket;
  final String remoteAddress;
  String? username;
  bool authenticated = false;
  final List<_CommandEntry> commandLog = [];
  final DateTime connectedAt = DateTime.now();

  _SshSession({
    required this.id,
    required this.socket,
    required this.remoteAddress,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': id,
        'remoteAddress': remoteAddress,
        'username': username,
        'authenticated': authenticated,
        'commandCount': commandLog.length,
        'connectedAt': connectedAt.toIso8601String(),
      };
}

class _CommandEntry {
  final String command;
  final String output;
  final int exitCode;
  final DateTime timestamp = DateTime.now();

  _CommandEntry({
    required this.command,
    required this.output,
    required this.exitCode,
  });

  Map<String, dynamic> toJson() => {
        'command': command,
        'output':
            output.length > 500 ? '${output.substring(0, 500)}...' : output,
        'exitCode': exitCode,
        'timestamp': timestamp.toIso8601String(),
      };
}
