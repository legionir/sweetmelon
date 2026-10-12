import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class HttpNativePlugin extends Plugin {
  @override
  String get name => 'http';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Native HTTP client plugin';

  @override
  List<String> get supportedMethods => [
        'request',
        'get',
        'post',
        'put',
        'patch',
        'delete',
        'download',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'request':
        return _request(
          (args['method'] as String? ?? 'GET').toUpperCase(),
          args,
        );
      case 'get':
        return _request('GET', args);
      case 'post':
        return _request('POST', args);
      case 'put':
        return _request('PUT', args);
      case 'patch':
        return _request('PATCH', args);
      case 'delete':
        return _request('DELETE', args);
      case 'download':
        return _download(args);
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> args,
  ) async {
    final url = args['url'] as String;
    final uri = _buildUri(
      url,
      args['query'] as Map<String, dynamic>?,
    );

    _validateUrlScheme(uri);

    final headers = _parseHeaders(args['headers']);
    final timeoutMs = (args['timeoutMs'] as num?)?.toInt() ?? 30000;
    final body = args['body'];
    final bodyType = args['bodyType'] as String? ?? 'auto';
    final responseType = args['responseType'] as String? ?? 'auto';

    final client = http.Client();

    try {
      final request = http.Request(method, uri);
      request.headers.addAll(headers);

      if (body != null) {
        _applyBody(
          request: request,
          body: body,
          bodyType: bodyType,
        );
      }

      final streamed =
          await client.send(request).timeout(Duration(milliseconds: timeoutMs));

      final response = await http.Response.fromStream(streamed);

      return {
        'ok': response.statusCode >= 200 && response.statusCode < 300,
        'statusCode': response.statusCode,
        'headers': response.headers,
        'url': response.request?.url.toString() ?? uri.toString(),
        'data': _decodeResponseBody(response, responseType),
      };
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _download(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    final uri = _buildUri(
      url,
      args['query'] as Map<String, dynamic>?,
    );

    _validateUrlScheme(uri);

    final headers = _parseHeaders(args['headers']);
    final timeoutMs = (args['timeoutMs'] as num?)?.toInt() ?? 60000;
    final overwrite = args['overwrite'] as bool? ?? true;
    final baseDir = args['baseDir'] as String? ?? 'temporary';
    final explicitPath = args['path'] as String?;
    final fileName = args['fileName'] as String? ?? _fileNameFromUri(uri);

    final root = await _resolveBaseDir(baseDir);

    final relative = explicitPath?.trim().isNotEmpty == true
        ? _safeRelativePath(explicitPath!)
        : p.join('downloads', fileName);

    final outputFile = File(p.join(root.path, relative));

    if (await outputFile.exists() && !overwrite) {
      return {
        'saved': false,
        'reason': 'already_exists',
        'path': outputFile.path,
      };
    }

    await outputFile.parent.create(recursive: true);

    final client = http.Client();

    try {
      final response = await client
          .get(uri, headers: headers)
          .timeout(Duration(milliseconds: timeoutMs));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return {
          'saved': false,
          'statusCode': response.statusCode,
          'reason': 'http_error',
        };
      }

      await outputFile.writeAsBytes(response.bodyBytes, flush: true);

      final mimeType = response.headers['content-type'] ??
          lookupMimeType(outputFile.path) ??
          'application/octet-stream';

      return {
        'saved': true,
        'statusCode': response.statusCode,
        'path': outputFile.path,
        'fileName': p.basename(outputFile.path),
        'size': response.bodyBytes.length,
        'mimeType': mimeType,
        'baseDir': baseDir,
      };
    } finally {
      client.close();
    }
  }

  Uri _buildUri(
    String url,
    Map<String, dynamic>? query,
  ) {
    final uri = Uri.parse(url);

    if (query == null || query.isEmpty) {
      return uri;
    }

    final merged = Map<String, String>.from(uri.queryParameters);
    query.forEach((key, value) {
      if (value != null) {
        merged[key] = value.toString();
      }
    });

    return uri.replace(queryParameters: merged);
  }

  void _validateUrlScheme(Uri uri) {
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError('Only http and https URLs are supported');
    }
  }

  Map<String, String> _parseHeaders(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
    return {};
  }

  void _applyBody({
    required http.Request request,
    required dynamic body,
    required String bodyType,
  }) {
    if (bodyType == 'json' ||
        (bodyType == 'auto' && (body is Map || body is List))) {
      request.headers.putIfAbsent('content-type', () => 'application/json');
      request.body = jsonEncode(body);
      return;
    }

    if (bodyType == 'form' && body is Map) {
      request.headers.putIfAbsent(
        'content-type',
        () => 'application/x-www-form-urlencoded',
      );
      request.bodyFields = body.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      return;
    }

    if (body is String) {
      request.body = body;
      return;
    }

    request.body = body.toString();
  }

  dynamic _decodeResponseBody(http.Response response, String responseType) {
    final contentType = response.headers['content-type'] ?? '';

    if (responseType == 'base64') {
      return base64Encode(response.bodyBytes);
    }

    if (responseType == 'json' ||
        (responseType == 'auto' && contentType.contains('application/json'))) {
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }

    if (responseType == 'bytes') {
      return base64Encode(response.bodyBytes);
    }

    return response.body;
  }

  Future<Directory> _resolveBaseDir(String baseDir) async {
    switch (baseDir) {
      case 'documents':
        return getApplicationDocumentsDirectory();
      case 'cache':
        return getApplicationCacheDirectory();
      case 'support':
        return getApplicationSupportDirectory();
      case 'temporary':
      case 'temp':
        return getTemporaryDirectory();
      default:
        throw FileSystemException('Unsupported baseDir: $baseDir');
    }
  }

  String _fileNameFromUri(Uri uri) {
    final name =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download.bin';
    return name.isEmpty ? 'download.bin' : name;
  }

  String _safeRelativePath(String input) {
    final normalized = p.normalize(input.replaceAll('\\', '/').trim());

    if (normalized.isEmpty || normalized == '.') {
      throw const FileSystemException('Invalid path');
    }

    if (p.isAbsolute(normalized) ||
        normalized.startsWith('..') ||
        normalized.contains('../') ||
        normalized == '..') {
      throw const FileSystemException('Path traversal detected');
    }

    return normalized;
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'request':
      case 'get':
      case 'post':
      case 'put':
      case 'patch':
      case 'delete':
      case 'download':
        final url = args['url'];
        if (url is! String || url.isEmpty) {
          return ValidationResult.invalid(
            'url is required and must be a non-empty string',
          );
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
