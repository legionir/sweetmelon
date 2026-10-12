import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef DownloadEventEmitter = Future<void> Function(
    String event, dynamic data);

class DownloadManagerPlugin extends Plugin {
  final DownloadEventEmitter? eventEmitter;

  final Map<String, _DownloadTask> _activeTasks = {};

  DownloadManagerPlugin({this.eventEmitter});

  @override
  String get name => 'downloadManager';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Download manager with progress events';

  @override
  List<String> get supportedMethods => [
        'download',
        'cancel',
        'cancelAll',
        'getActive',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'download':
        return _download(args);
      case 'cancel':
        return _cancel(args);
      case 'cancelAll':
        return _cancelAll();
      case 'getActive':
        return _getActive();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'activeDownloads': _activeTasks.length,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _download(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    final uri = Uri.parse(url);
    final fileName = args['fileName'] as String? ?? _fileNameFromUri(uri);
    final baseDir = args['baseDir'] as String? ?? 'documents';
    final subPath = args['path'] as String? ?? 'downloads';
    final overwrite = args['overwrite'] as bool? ?? true;
    final taskId = args['taskId'] as String? ??
        'dl_${DateTime.now().millisecondsSinceEpoch}';

    final headers = _parseHeaders(args['headers']);

    final root = await _resolveBaseDir(baseDir);
    final outputPath = p.join(root.path, subPath, fileName);
    final outputFile = File(outputPath);

    if (await outputFile.exists() && !overwrite) {
      return {
        'taskId': taskId,
        'saved': false,
        'reason': 'already_exists',
        'path': outputPath,
      };
    }

    await outputFile.parent.create(recursive: true);

    final client = http.Client();
    final task = _DownloadTask(taskId: taskId, client: client);
    _activeTasks[taskId] = task;

    try {
      final request = http.Request('GET', uri);
      request.headers.addAll(headers);

      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _activeTasks.remove(taskId);
        return {
          'taskId': taskId,
          'saved': false,
          'reason': 'http_error',
          'statusCode': response.statusCode,
        };
      }

      final totalBytes = response.contentLength ?? -1;
      var receivedBytes = 0;
      final sink = outputFile.openWrite();

      int lastProgressPercent = -1;

      await for (final chunk in response.stream) {
        if (task.cancelled) {
          await sink.close();
          if (await outputFile.exists()) {
            await outputFile.delete();
          }
          _activeTasks.remove(taskId);
          return {
            'taskId': taskId,
            'saved': false,
            'reason': 'cancelled',
          };
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        final percent =
            totalBytes > 0 ? ((receivedBytes / totalBytes) * 100).round() : -1;

        if (percent != lastProgressPercent) {
          lastProgressPercent = percent;

          if (eventEmitter != null) {
            eventEmitter!('download.progress', {
              'taskId': taskId,
              'fileName': fileName,
              'receivedBytes': receivedBytes,
              'totalBytes': totalBytes,
              'percent': percent,
            });
          }
        }
      }

      await sink.flush();
      await sink.close();

      _activeTasks.remove(taskId);

      final mimeType = lookupMimeType(outputPath) ?? 'application/octet-stream';

      final result = {
        'taskId': taskId,
        'saved': true,
        'path': outputPath,
        'fileName': fileName,
        'size': receivedBytes,
        'mimeType': mimeType,
        'baseDir': baseDir,
      };

      if (eventEmitter != null) {
        eventEmitter!('download.complete', result);
      }

      return result;
    } catch (e) {
      _activeTasks.remove(taskId);
      BridgeLogger.error('DownloadManager', 'Download error: $e');

      if (eventEmitter != null) {
        eventEmitter!('download.error', {
          'taskId': taskId,
          'error': e.toString(),
        });
      }

      return {
        'taskId': taskId,
        'saved': false,
        'reason': 'error',
        'error': e.toString(),
      };
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _cancel(Map<String, dynamic> args) async {
    final taskId = args['taskId'] as String;
    final task = _activeTasks[taskId];

    if (task == null) {
      return {'taskId': taskId, 'cancelled': false, 'reason': 'not_found'};
    }

    task.cancelled = true;
    task.client.close();

    return {'taskId': taskId, 'cancelled': true};
  }

  Future<Map<String, dynamic>> _cancelAll() async {
    final count = _activeTasks.length;

    for (final task in _activeTasks.values) {
      task.cancelled = true;
      task.client.close();
    }

    _activeTasks.clear();
    return {'cancelled': count};
  }

  Map<String, dynamic> _getActive() {
    return {
      'count': _activeTasks.length,
      'tasks': _activeTasks.keys.toList(),
    };
  }

  Map<String, String> _parseHeaders(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  String _fileNameFromUri(Uri uri) {
    final name =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download.bin';
    return name.isEmpty ? 'download.bin' : name;
  }

  Future<Directory> _resolveBaseDir(String baseDir) async {
    switch (baseDir) {
      case 'documents':
        return getApplicationDocumentsDirectory();
      case 'cache':
        return getApplicationCacheDirectory();
      case 'temporary':
        return getTemporaryDirectory();
      default:
        return getApplicationDocumentsDirectory();
    }
  }

  @override
  Future<void> onDispose() async {
    await _cancelAll();
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'download':
        final url = args['url'];
        if (url is! String || url.isEmpty) {
          return ValidationResult.invalid('url is required');
        }
        return ValidationResult.valid();

      case 'cancel':
        final taskId = args['taskId'];
        if (taskId is! String || taskId.isEmpty) {
          return ValidationResult.invalid('taskId is required');
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}

class _DownloadTask {
  final String taskId;
  final http.Client client;
  bool cancelled = false;

  _DownloadTask({
    required this.taskId,
    required this.client,
  });
}
