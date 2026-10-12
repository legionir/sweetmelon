import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef FtpServerEventEmitter = Future<void> Function(
    String event, dynamic data);

class FtpServerPlugin extends Plugin {
  final FtpServerEventEmitter? eventEmitter;

  ServerSocket? _server;
  String? _rootDir;
  int _port = 0;
  bool _running = false;
  final Map<String, _FtpSession> _sessions = {};
  int _sessionCounter = 0;

  String _username = 'anonymous';
  String _password = '';
  bool _allowAnonymous = true;

  FtpServerPlugin({this.eventEmitter});

  @override
  String get name => 'ftpServer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'FTP server for file sharing on local network';

  @override
  List<String> get supportedMethods => [
        'start',
        'stop',
        'configure',
        'getClients',
        'disconnectClient',
        'getStats',
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
      case 'getClients':
        return _getClients();
      case 'disconnectClient':
        return _disconnectClient(args);
      case 'getStats':
        return _getStats();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'running': _running,
          'port': _port,
          'rootDir': _rootDir,
          'clients': _sessions.length,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _configure(Map<String, dynamic> args) {
    _username = args['username'] as String? ?? 'anonymous';
    _password = args['password'] as String? ?? '';
    _allowAnonymous = args['allowAnonymous'] as bool? ?? true;

    return {
      'configured': true,
      'username': _username,
      'allowAnonymous': _allowAnonymous,
    };
  }

  Future<Map<String, dynamic>> _start(Map<String, dynamic> args) async {
    if (_running) {
      return {
        'started': true,
        'alreadyRunning': true,
        'port': _port,
      };
    }

    final port = (args['port'] as num?)?.toInt() ?? 2121;
    final host = args['host'] as String? ?? '0.0.0.0';
    _rootDir = args['rootDir'] as String;

    if (_rootDir == null || _rootDir!.isEmpty) {
      return {'started': false, 'reason': 'rootDir is required'};
    }

    final rootDirectory = Directory(_rootDir!);
    if (!await rootDirectory.exists()) {
      await rootDirectory.create(recursive: true);
    }

    try {
      _server = await ServerSocket.bind(
        host == '0.0.0.0' ? InternetAddress.anyIPv4 : InternetAddress(host),
        port,
      );

      _port = _server!.port;
      _running = true;

      _server!.listen(_handleNewConnection);

      BridgeLogger.info('FtpServer', 'Started on port $_port, root: $_rootDir');

      eventEmitter?.call('ftpServer.started', {
        'port': _port,
        'rootDir': _rootDir,
      });

      return {
        'started': true,
        'alreadyRunning': false,
        'port': _port,
        'rootDir': _rootDir,
        'url': 'ftp://$host:$_port',
      };
    } catch (e) {
      return {'started': false, 'error': e.toString()};
    }
  }

  void _handleNewConnection(Socket client) {
    _sessionCounter++;
    final sessionId = 'ftp_client_$_sessionCounter';

    final session = _FtpSession(
      id: sessionId,
      socket: client,
      rootDir: _rootDir!,
      remoteAddress: client.remoteAddress.address,
    );

    _sessions[sessionId] = session;

    BridgeLogger.info('FtpServer', 'Client connected: $sessionId');

    eventEmitter?.call('ftpServer.clientConnected', {
      'sessionId': sessionId,
      'remoteAddress': client.remoteAddress.address,
      'totalClients': _sessions.length,
    });

    // Welcome message
    client.write('220 Sweetmelon FTP Server Ready\r\n');

    client.listen(
      (data) async {
        final command = utf8.decode(data).trim();
        await _handleCommand(session, command);
      },
      onDone: () {
        _sessions.remove(sessionId);
        eventEmitter?.call('ftpServer.clientDisconnected', {
          'sessionId': sessionId,
        });
      },
      onError: (e) {
        _sessions.remove(sessionId);
      },
    );
  }

  Future<void> _handleCommand(_FtpSession session, String rawCommand) async {
    final parts = rawCommand.split(' ');
    final cmd = parts[0].toUpperCase();
    final arg = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    BridgeLogger.debug('FtpServer', '[${session.id}] $cmd $arg');

    eventEmitter?.call('ftpServer.command', {
      'sessionId': session.id,
      'command': cmd,
      'argument': arg,
    });

    switch (cmd) {
      case 'USER':
        session.username = arg;
        if (_allowAnonymous && arg == 'anonymous') {
          session.authenticated = true;
          session.socket.write('230 Login successful\r\n');
        } else {
          session.socket.write('331 Password required\r\n');
        }
        break;

      case 'PASS':
        if (session.username == _username && arg == _password) {
          session.authenticated = true;
          session.socket.write('230 Login successful\r\n');
        } else if (_allowAnonymous && session.username == 'anonymous') {
          session.authenticated = true;
          session.socket.write('230 Anonymous login accepted\r\n');
        } else {
          session.socket.write('530 Login incorrect\r\n');
        }
        break;

      case 'PWD':
        if (!session.authenticated) {
          session.socket.write('530 Not logged in\r\n');
          break;
        }
        session.socket.write('257 "${session.currentDir}"\r\n');
        break;

      case 'CWD':
        if (!session.authenticated) {
          session.socket.write('530 Not logged in\r\n');
          break;
        }
        final newDir = session.resolveDir(arg);
        if (await Directory(p.join(_rootDir!, newDir)).exists()) {
          session.currentDir = newDir;
          session.socket.write('250 Directory changed\r\n');
        } else {
          session.socket.write('550 Directory not found\r\n');
        }
        break;

      case 'LIST':
        if (!session.authenticated) {
          session.socket.write('530 Not logged in\r\n');
          break;
        }
        await _handleList(session, arg);
        break;

      case 'PASV':
        await _handlePasv(session);
        break;

      case 'TYPE':
        session.socket.write('200 Type set\r\n');
        break;

      case 'SYST':
        session.socket.write('215 UNIX Type: L8\r\n');
        break;

      case 'FEAT':
        session.socket.write('211-Features:\r\n PASV\r\n UTF8\r\n211 End\r\n');
        break;

      case 'SIZE':
        if (!session.authenticated) {
          session.socket.write('530 Not logged in\r\n');
          break;
        }
        final filePath = p.join(_rootDir!, session.resolveDir(arg));
        final file = File(filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          session.socket.write('213 ${stat.size}\r\n');
        } else {
          session.socket.write('550 File not found\r\n');
        }
        break;

      case 'RETR':
        if (!session.authenticated) {
          session.socket.write('530 Not logged in\r\n');
          break;
        }
        await _handleRetr(session, arg);
        break;

      case 'STOR':
        if (!session.authenticated) {
          session.socket.write('530 Not logged in\r\n');
          break;
        }
        await _handleStor(session, arg);
        break;

      case 'DELE':
        if (!session.authenticated) {
          session.socket.write('530 Not logged in\r\n');
          break;
        }
        final delPath = p.join(_rootDir!, session.resolveDir(arg));
        final delFile = File(delPath);
        if (await delFile.exists()) {
          await delFile.delete();
          session.socket.write('250 File deleted\r\n');
          session.filesTransferred++;
        } else {
          session.socket.write('550 File not found\r\n');
        }
        break;

      case 'MKD':
        if (!session.authenticated) {
          session.socket.write('530 Not logged in\r\n');
          break;
        }
        final mkdPath = p.join(_rootDir!, session.resolveDir(arg));
        await Directory(mkdPath).create(recursive: true);
        session.socket.write('257 "$arg" created\r\n');
        break;

      case 'RMD':
        if (!session.authenticated) {
          session.socket.write('530 Not logged in\r\n');
          break;
        }
        final rmdPath = p.join(_rootDir!, session.resolveDir(arg));
        final rmdDir = Directory(rmdPath);
        if (await rmdDir.exists()) {
          await rmdDir.delete(recursive: true);
          session.socket.write('250 Directory removed\r\n');
        } else {
          session.socket.write('550 Directory not found\r\n');
        }
        break;

      case 'QUIT':
        session.socket.write('221 Goodbye\r\n');
        await session.socket.close();
        _sessions.remove(session.id);
        break;

      case 'NOOP':
        session.socket.write('200 OK\r\n');
        break;

      default:
        session.socket.write('502 Command not implemented\r\n');
    }
  }

  Future<void> _handlePasv(_FtpSession session) async {
    try {
      final dataServer = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      session.dataServer = dataServer;

      final port = dataServer.port;
      final p1 = port >> 8;
      final p2 = port & 0xFF;

      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      var ip = InternetAddress.loopbackIPv4.address.replaceAll('.', ',');
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) {
            ip = address.address.replaceAll('.', ',');
            break;
          }
        }
        if (ip != InternetAddress.loopbackIPv4.address.replaceAll('.', ',')) {
          break;
        }
      }

      session.socket.write('227 Entering Passive Mode ($ip,$p1,$p2)\r\n');
    } catch (e) {
      session.socket.write('425 Cannot open passive connection\r\n');
    }
  }

  Future<void> _handleList(_FtpSession session, String arg) async {
    if (session.dataServer == null) {
      session.socket.write('425 Use PASV first\r\n');
      return;
    }

    session.socket.write('150 Opening data connection\r\n');

    final dataClient = await session.dataServer!.first;

    final dirPath = arg.isNotEmpty
        ? p.join(_rootDir!, session.resolveDir(arg))
        : p.join(_rootDir!, session.currentDir);

    final dir = Directory(dirPath);

    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        final stat = await entity.stat();
        final name = p.basename(entity.path);
        final isDir = entity is Directory;
        final perm = isDir ? 'drwxr-xr-x' : '-rw-r--r--';
        final size = stat.size.toString().padLeft(10);
        final date = _formatFtpDate(stat.modified);

        dataClient.write('$perm   1 ftp ftp $size $date $name\r\n');
      }
    }

    await dataClient.close();
    session.dataServer?.close();
    session.dataServer = null;

    session.socket.write('226 Transfer complete\r\n');
  }

  Future<void> _handleRetr(_FtpSession session, String fileName) async {
    if (session.dataServer == null) {
      session.socket.write('425 Use PASV first\r\n');
      return;
    }

    final filePath = p.join(_rootDir!, session.resolveDir(fileName));
    final file = File(filePath);

    if (!await file.exists()) {
      session.socket.write('550 File not found\r\n');
      return;
    }

    session.socket.write('150 Opening data connection\r\n');

    final dataClient = await session.dataServer!.first;
    final bytes = await file.readAsBytes();
    dataClient.add(bytes);
    await dataClient.close();

    session.dataServer?.close();
    session.dataServer = null;
    session.bytesTransferred += bytes.length;
    session.filesTransferred++;

    session.socket.write('226 Transfer complete\r\n');

    eventEmitter?.call('ftpServer.fileDownloaded', {
      'sessionId': session.id,
      'file': fileName,
      'size': bytes.length,
    });
  }

  Future<void> _handleStor(_FtpSession session, String fileName) async {
    if (session.dataServer == null) {
      session.socket.write('425 Use PASV first\r\n');
      return;
    }

    session.socket.write('150 Opening data connection\r\n');

    final dataClient = await session.dataServer!.first;
    final filePath = p.join(_rootDir!, session.resolveDir(fileName));
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final sink = file.openWrite();
    int totalBytes = 0;

    await for (final chunk in dataClient) {
      sink.add(chunk);
      totalBytes += chunk.length;
    }

    await sink.flush();
    await sink.close();

    session.dataServer?.close();
    session.dataServer = null;
    session.bytesTransferred += totalBytes;
    session.filesTransferred++;

    session.socket.write('226 Transfer complete\r\n');

    eventEmitter?.call('ftpServer.fileUploaded', {
      'sessionId': session.id,
      'file': fileName,
      'size': totalBytes,
    });
  }

  Future<Map<String, dynamic>> _stop() async {
    if (!_running) return {'stopped': false, 'reason': 'not_running'};

    for (final session in _sessions.values) {
      session.socket.write('421 Server shutting down\r\n');
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
      session.socket.write('421 Disconnected by server\r\n');
      await session.socket.close();
      return {'disconnected': true};
    }

    return {'disconnected': false, 'reason': 'not_found'};
  }

  Map<String, dynamic> _getStats() {
    int totalBytes = 0;
    int totalFiles = 0;
    for (final s in _sessions.values) {
      totalBytes += s.bytesTransferred;
      totalFiles += s.filesTransferred;
    }

    return {
      'running': _running,
      'port': _port,
      'rootDir': _rootDir,
      'totalClients': _sessions.length,
      'totalBytesTransferred': totalBytes,
      'totalFilesTransferred': totalFiles,
    };
  }

  String _formatFtpDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'start':
        if (args['rootDir'] is! String || (args['rootDir'] as String).isEmpty) {
          return ValidationResult.invalid('rootDir is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}

class _FtpSession {
  final String id;
  final Socket socket;
  final String rootDir;
  final String remoteAddress;
  String username = '';
  bool authenticated = false;
  String currentDir = '/';
  ServerSocket? dataServer;
  int bytesTransferred = 0;
  int filesTransferred = 0;
  final DateTime connectedAt = DateTime.now();

  _FtpSession({
    required this.id,
    required this.socket,
    required this.rootDir,
    required this.remoteAddress,
  });

  String resolveDir(String path) {
    if (path.startsWith('/')) return path;
    return p.normalize(p.join(currentDir, path));
  }

  Map<String, dynamic> toJson() => {
        'sessionId': id,
        'remoteAddress': remoteAddress,
        'username': username,
        'authenticated': authenticated,
        'currentDir': currentDir,
        'bytesTransferred': bytesTransferred,
        'filesTransferred': filesTransferred,
        'connectedAt': connectedAt.toIso8601String(),
      };
}
