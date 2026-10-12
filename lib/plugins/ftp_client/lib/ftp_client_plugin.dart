import 'dart:async';
import 'dart:io';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef FtpEventEmitter = Future<void> Function(String event, dynamic data);

class FtpClientPlugin extends Plugin {
  final FtpEventEmitter? eventEmitter;

  Socket? _controlSocket;
  bool _connected = false;
  String? _host;
  int _port = 21;
  String _lastResponse = '';

  FtpClientPlugin({this.eventEmitter});

  @override
  String get name => 'ftpClient';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'FTP client for file transfer';

  @override
  List<String> get supportedMethods => [
        'connect',
        'disconnect',
        'login',
        'listFiles',
        'downloadFile',
        'uploadFile',
        'deleteFile',
        'makeDirectory',
        'removeDirectory',
        'getCurrentDirectory',
        'changeDirectory',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    await _disconnect();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'connect':
        return _connect(args);
      case 'disconnect':
        return _disconnect();
      case 'login':
        return _login(args);
      case 'listFiles':
        return _listFiles(args);
      case 'downloadFile':
        return _downloadFile(args);
      case 'uploadFile':
        return _uploadFile(args);
      case 'deleteFile':
        return _deleteFile(args);
      case 'makeDirectory':
        return _makeDirectory(args);
      case 'removeDirectory':
        return _removeDirectory(args);
      case 'getCurrentDirectory':
        return _getCurrentDirectory();
      case 'changeDirectory':
        return _changeDirectory(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'connected': _connected,
          'host': _host,
          'port': _port,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _connect(Map<String, dynamic> args) async {
    _host = args['host'] as String;
    _port = (args['port'] as num?)?.toInt() ?? 21;
    final timeoutMs = (args['timeoutMs'] as num?)?.toInt() ?? 10000;

    try {
      _controlSocket = await Socket.connect(
        _host!,
        _port,
        timeout: Duration(milliseconds: timeoutMs),
      );

      _connected = true;

      final response = await _readResponse();

      BridgeLogger.info('FTP', 'Connected to $_host:$_port');

      return {
        'connected': true,
        'host': _host,
        'port': _port,
        'response': response,
      };
    } catch (e) {
      _connected = false;
      return {'connected': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _login(Map<String, dynamic> args) async {
    final username = args['username'] as String? ?? 'anonymous';
    final password = args['password'] as String? ?? '';

    if (!_connected) return {'loggedIn': false, 'reason': 'not_connected'};

    try {
      await _sendCommand('USER $username');
      final userResponse = await _readResponse();

      if (userResponse.startsWith('331')) {
        await _sendCommand('PASS $password');
        final passResponse = await _readResponse();

        if (passResponse.startsWith('230')) {
          return {'loggedIn': true, 'response': passResponse};
        }

        return {'loggedIn': false, 'response': passResponse};
      }

      return {'loggedIn': false, 'response': userResponse};
    } catch (e) {
      return {'loggedIn': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _listFiles(Map<String, dynamic> args) async {
    if (!_connected) return {'files': <dynamic>[], 'reason': 'not_connected'};

    final path = args['path'] as String? ?? '.';

    try {
      // Enter passive mode
      await _sendCommand('PASV');
      final pasvResponse = await _readResponse();
      final dataPort = _parsePasvPort(pasvResponse);

      if (dataPort == null) {
        return {'files': <dynamic>[], 'error': 'PASV failed'};
      }

      final dataSocket = await Socket.connect(_host!, dataPort);

      await _sendCommand('LIST $path');
      await _readResponse();

      final data = StringBuffer();
      await for (final chunk in dataSocket) {
        data.write(String.fromCharCodes(chunk));
      }
      await dataSocket.close();

      await _readResponse(); // transfer complete

      final lines =
          data.toString().split('\n').where((l) => l.trim().isNotEmpty);
      final files = lines.map((line) => _parseFtpLine(line)).toList();

      return {'files': files, 'count': files.length, 'path': path};
    } catch (e) {
      return {'files': <dynamic>[], 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _downloadFile(Map<String, dynamic> args) async {
    if (!_connected) return {'downloaded': false, 'reason': 'not_connected'};

    final remotePath = args['remotePath'] as String;
    final localPath = args['localPath'] as String;

    try {
      await _sendCommand('TYPE I'); // binary mode
      await _readResponse();

      await _sendCommand('PASV');
      final pasvResponse = await _readResponse();
      final dataPort = _parsePasvPort(pasvResponse);

      if (dataPort == null) {
        return {'downloaded': false, 'error': 'PASV failed'};
      }

      final dataSocket = await Socket.connect(_host!, dataPort);

      await _sendCommand('RETR $remotePath');
      await _readResponse();

      final file = File(localPath);
      await file.parent.create(recursive: true);
      final sink = file.openWrite();

      int totalBytes = 0;

      await for (final chunk in dataSocket) {
        sink.add(chunk);
        totalBytes += chunk.length;
      }

      await sink.flush();
      await sink.close();
      await dataSocket.close();

      await _readResponse();

      eventEmitter?.call('ftp.downloaded', {
        'remotePath': remotePath,
        'localPath': localPath,
        'size': totalBytes,
      });

      return {
        'downloaded': true,
        'localPath': localPath,
        'size': totalBytes,
      };
    } catch (e) {
      return {'downloaded': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _uploadFile(Map<String, dynamic> args) async {
    if (!_connected) return {'uploaded': false, 'reason': 'not_connected'};

    final localPath = args['localPath'] as String;
    final remotePath = args['remotePath'] as String;

    final file = File(localPath);
    if (!await file.exists()) {
      return {'uploaded': false, 'reason': 'file_not_found'};
    }

    try {
      await _sendCommand('TYPE I');
      await _readResponse();

      await _sendCommand('PASV');
      final pasvResponse = await _readResponse();
      final dataPort = _parsePasvPort(pasvResponse);

      if (dataPort == null) {
        return {'uploaded': false, 'error': 'PASV failed'};
      }

      final dataSocket = await Socket.connect(_host!, dataPort);

      await _sendCommand('STOR $remotePath');
      await _readResponse();

      final bytes = await file.readAsBytes();
      dataSocket.add(bytes);
      await dataSocket.flush();
      await dataSocket.close();

      await _readResponse();

      eventEmitter?.call('ftp.uploaded', {
        'localPath': localPath,
        'remotePath': remotePath,
        'size': bytes.length,
      });

      return {
        'uploaded': true,
        'remotePath': remotePath,
        'size': bytes.length,
      };
    } catch (e) {
      return {'uploaded': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _deleteFile(Map<String, dynamic> args) async {
    if (!_connected) return {'deleted': false, 'reason': 'not_connected'};
    final path = args['path'] as String;
    await _sendCommand('DELE $path');
    final response = await _readResponse();
    return {'deleted': response.startsWith('250'), 'response': response};
  }

  Future<Map<String, dynamic>> _makeDirectory(Map<String, dynamic> args) async {
    if (!_connected) return {'created': false, 'reason': 'not_connected'};
    final path = args['path'] as String;
    await _sendCommand('MKD $path');
    final response = await _readResponse();
    return {'created': response.startsWith('257'), 'response': response};
  }

  Future<Map<String, dynamic>> _removeDirectory(
      Map<String, dynamic> args) async {
    if (!_connected) return {'removed': false, 'reason': 'not_connected'};
    final path = args['path'] as String;
    await _sendCommand('RMD $path');
    final response = await _readResponse();
    return {'removed': response.startsWith('250'), 'response': response};
  }

  Future<Map<String, dynamic>> _getCurrentDirectory() async {
    if (!_connected) return {'path': null, 'reason': 'not_connected'};
    await _sendCommand('PWD');
    final response = await _readResponse();
    final match = RegExp(r'"(.+)"').firstMatch(response);
    return {'path': match?.group(1) ?? '/', 'response': response};
  }

  Future<Map<String, dynamic>> _changeDirectory(
      Map<String, dynamic> args) async {
    if (!_connected) return {'changed': false, 'reason': 'not_connected'};
    final path = args['path'] as String;
    await _sendCommand('CWD $path');
    final response = await _readResponse();
    return {'changed': response.startsWith('250'), 'response': response};
  }

  Future<Map<String, dynamic>> _disconnect() async {
    if (!_connected) return {'disconnected': false};

    try {
      await _sendCommand('QUIT');
      await _readResponse();
    } catch (_) {}

    _controlSocket?.close();
    _controlSocket = null;
    _connected = false;

    return {'disconnected': true};
  }

  // ── Helpers ──

  Future<void> _sendCommand(String command) async {
    _controlSocket?.write('$command\r\n');
    await _controlSocket?.flush();
  }

  Future<String> _readResponse() async {
    final completer = Completer<String>();
    final buffer = StringBuffer();

    late StreamSubscription sub;
    sub = _controlSocket!.listen(
      (data) {
        buffer.write(String.fromCharCodes(data));
        final content = buffer.toString();

        if (content.contains('\r\n') &&
            RegExp(r'^\d{3} ', multiLine: true).hasMatch(content)) {
          sub.cancel();
          _lastResponse = content.trim();
          completer.complete(_lastResponse);
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        sub.cancel();
        return buffer.toString().trim();
      },
    );
  }

  int? _parsePasvPort(String response) {
    final match =
        RegExp(r'\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)').firstMatch(response);
    if (match == null) return null;
    final p1 = int.parse(match.group(5)!);
    final p2 = int.parse(match.group(6)!);
    return p1 * 256 + p2;
  }

  Map<String, dynamic> _parseFtpLine(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 9) {
      return {'raw': line.trim()};
    }

    return {
      'permissions': parts[0],
      'type': parts[0].startsWith('d') ? 'directory' : 'file',
      'size': int.tryParse(parts[4]) ?? 0,
      'date': '${parts[5]} ${parts[6]} ${parts[7]}',
      'name': parts.sublist(8).join(' '),
    };
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'connect':
        if (args['host'] is! String) {
          return ValidationResult.invalid('host is required');
        }
        return ValidationResult.valid();
      case 'downloadFile':
        if (args['remotePath'] is! String) {
          return ValidationResult.invalid('remotePath is required');
        }
        if (args['localPath'] is! String) {
          return ValidationResult.invalid('localPath is required');
        }
        return ValidationResult.valid();
      case 'uploadFile':
        if (args['localPath'] is! String) {
          return ValidationResult.invalid('localPath is required');
        }
        if (args['remotePath'] is! String) {
          return ValidationResult.invalid('remotePath is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
