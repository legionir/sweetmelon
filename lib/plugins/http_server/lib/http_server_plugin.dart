import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef HttpServerEventEmitter = Future<void> Function(
    String event, dynamic data);

class HttpServerPlugin extends Plugin {
  final HttpServerEventEmitter? eventEmitter;

  final Map<String, _ManagedServer> _servers = {};
  final Map<String, List<_RouteHandler>> _routes = {};

  HttpServerPlugin({this.eventEmitter});

  @override
  String get name => 'httpServer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Local HTTP/HTTPS server plugin';

  @override
  List<String> get supportedMethods => [
        'start',
        'stop',
        'stopAll',
        'addRoute',
        'removeRoute',
        'serveDirectory',
        'getServers',
        'getRequests',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    await _stopAll();
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
      case 'addRoute':
        return _addRoute(args);
      case 'removeRoute':
        return _removeRoute(args);
      case 'serveDirectory':
        return _serveDirectory(args);
      case 'getServers':
        return _getServers();
      case 'getRequests':
        return _getRequests(args);
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
    final id = args['id'] as String? ??
        'server_${DateTime.now().millisecondsSinceEpoch}';
    final port = (args['port'] as num?)?.toInt() ?? 0;
    final host = args['host'] as String? ?? '0.0.0.0';
    final enableCors = args['cors'] as bool? ?? true;

    if (_servers.containsKey(id)) {
      final existing = _servers[id]!;
      return {
        'started': true,
        'alreadyRunning': true,
        'id': id,
        'port': existing.server.port,
        'url': 'http://$host:${existing.server.port}',
      };
    }

    try {
      final server = await HttpServer.bind(
        host == '0.0.0.0' ? InternetAddress.anyIPv4 : InternetAddress(host),
        port,
      );

      final managed = _ManagedServer(
        id: id,
        server: server,
        enableCors: enableCors,
      );

      _servers[id] = managed;
      _routes[id] ??= [];

      server.listen(
        (request) => _handleRequest(id, request, managed),
        onError: (error) {
          BridgeLogger.error('HttpServer', '[$id] Error: $error');
          eventEmitter?.call('httpServer.error', {
            'serverId': id,
            'error': error.toString(),
          });
        },
      );

      BridgeLogger.info('HttpServer', '[$id] Started on port ${server.port}');

      eventEmitter?.call('httpServer.started', {
        'serverId': id,
        'port': server.port,
        'host': host,
      });

      return {
        'started': true,
        'alreadyRunning': false,
        'id': id,
        'port': server.port,
        'url': 'http://$host:${server.port}',
      };
    } catch (e) {
      BridgeLogger.error('HttpServer', 'Start failed: $e');
      return {'started': false, 'error': e.toString()};
    }
  }

  Future<void> _handleRequest(
    String serverId,
    HttpRequest request,
    _ManagedServer managed,
  ) async {
    managed.requestCount++;

    final method = request.method.toUpperCase();
    final path = request.uri.path;

    // CORS
    if (managed.enableCors) {
      request.response.headers
        ..set('Access-Control-Allow-Origin', '*')
        ..set('Access-Control-Allow-Methods',
            'GET, POST, PUT, DELETE, OPTIONS, PATCH')
        ..set('Access-Control-Allow-Headers', '*');

      if (method == 'OPTIONS') {
        request.response
          ..statusCode = HttpStatus.ok
          ..close();
        return;
      }
    }

    // Route matching
    final routes = _routes[serverId] ?? [];

    for (final route in routes) {
      if (_matchRoute(route, method, path)) {
        await _executeRoute(route, request);
        return;
      }
    }

    // Static file serving
    if (managed.staticDir != null) {
      await _serveStaticFile(request, managed.staticDir!);
      return;
    }

    // Emit request event for JS handling
    final body = await _readBody(request);

    eventEmitter?.call('httpServer.request', {
      'serverId': serverId,
      'method': method,
      'path': path,
      'query': request.uri.queryParameters,
      'headers': request.headers.toString(),
      'body': body,
      'remoteAddress': request.connectionInfo?.remoteAddress.address,
    });

    // Default 404
    request.response
      ..statusCode = HttpStatus.notFound
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': 'Not Found', 'path': path}))
      ..close();
  }

  bool _matchRoute(_RouteHandler route, String method, String path) {
    if (route.method != '*' && route.method != method) return false;

    if (route.path == path) return true;

    // Simple wildcard
    if (route.path.endsWith('*')) {
      final prefix = route.path.substring(0, route.path.length - 1);
      return path.startsWith(prefix);
    }

    // Pattern matching with :params
    final routeSegments = route.path.split('/');
    final pathSegments = path.split('/');

    if (routeSegments.length != pathSegments.length) return false;

    for (int i = 0; i < routeSegments.length; i++) {
      if (routeSegments[i].startsWith(':')) continue;
      if (routeSegments[i] != pathSegments[i]) return false;
    }

    return true;
  }

  Future<void> _executeRoute(_RouteHandler route, HttpRequest request) async {
    try {
      final body = await _readBody(request);

      // Extract path params
      final params = <String, String>{};
      final routeSegments = route.path.split('/');
      final pathSegments = request.uri.path.split('/');
      for (int i = 0;
          i < routeSegments.length && i < pathSegments.length;
          i++) {
        if (routeSegments[i].startsWith(':')) {
          params[routeSegments[i].substring(1)] = pathSegments[i];
        }
      }

      request.response
        ..statusCode = route.statusCode
        ..headers.contentType = ContentType.parse(route.contentType);

      if (route.responseBody != null) {
        if (route.responseBody is Map || route.responseBody is List) {
          request.response.write(jsonEncode(route.responseBody));
        } else {
          request.response.write(route.responseBody.toString());
        }
      } else {
        request.response.write(jsonEncode({
          'path': request.uri.path,
          'method': request.method,
          'params': params,
          'query': request.uri.queryParameters,
          'body': body,
        }));
      }

      request.response.close();
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write(jsonEncode({'error': e.toString()}))
        ..close();
    }
  }

  Future<String?> _readBody(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      return body.isNotEmpty ? body : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _serveStaticFile(HttpRequest request, String baseDir) async {
    var filePath = request.uri.path;
    if (filePath == '/' || filePath.isEmpty) filePath = '/index.html';

    // Path traversal protection
    if (filePath.contains('..')) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('Forbidden')
        ..close();
      return;
    }

    final fullPath = p.join(baseDir, filePath.substring(1));
    final file = File(fullPath);

    if (await file.exists()) {
      final mimeType = lookupMimeType(fullPath) ?? 'application/octet-stream';
      final bytes = await file.readAsBytes();

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.parse(mimeType)
        ..contentLength = bytes.length
        ..add(bytes)
        ..close();
    } else {
      // SPA fallback
      final indexPath = p.join(baseDir, 'index.html');
      final indexFile = File(indexPath);

      if (await indexFile.exists()) {
        final bytes = await indexFile.readAsBytes();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..add(bytes)
          ..close();
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not Found')
          ..close();
      }
    }
  }

  Map<String, dynamic> _addRoute(Map<String, dynamic> args) {
    final serverId = args['serverId'] as String;
    final routeMethod = (args['method'] as String? ?? 'GET').toUpperCase();
    final routePath = args['path'] as String;
    final statusCode = (args['statusCode'] as num?)?.toInt() ?? 200;
    final contentType = args['contentType'] as String? ?? 'application/json';
    final responseBody = args['response'];

    _routes[serverId] ??= [];
    _routes[serverId]!.add(_RouteHandler(
      method: routeMethod,
      path: routePath,
      statusCode: statusCode,
      contentType: contentType,
      responseBody: responseBody,
    ));

    BridgeLogger.info(
        'HttpServer', '[$serverId] Route added: $routeMethod $routePath');

    return {
      'added': true,
      'method': routeMethod,
      'path': routePath,
    };
  }

  Map<String, dynamic> _removeRoute(Map<String, dynamic> args) {
    final serverId = args['serverId'] as String;
    final routePath = args['path'] as String;

    final routes = _routes[serverId];
    if (routes != null) {
      routes.removeWhere((r) => r.path == routePath);
      return {'removed': true, 'path': routePath};
    }

    return {'removed': false, 'reason': 'server_not_found'};
  }

  Future<Map<String, dynamic>> _serveDirectory(
      Map<String, dynamic> args) async {
    final serverId = args['serverId'] as String;
    final directory = args['directory'] as String;

    final managed = _servers[serverId];
    if (managed == null) {
      return {'set': false, 'reason': 'server_not_found'};
    }

    if (!await Directory(directory).exists()) {
      return {'set': false, 'reason': 'directory_not_found'};
    }

    managed.staticDir = directory;

    BridgeLogger.info('HttpServer', '[$serverId] Serving: $directory');

    return {
      'set': true,
      'directory': directory,
      'url': 'http://localhost:${managed.server.port}',
    };
  }

  Future<Map<String, dynamic>> _stop(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final managed = _servers.remove(id);
    _routes.remove(id);

    if (managed != null) {
      await managed.server.close(force: true);
      BridgeLogger.info('HttpServer', '[$id] Stopped');
      return {'stopped': true, 'id': id};
    }

    return {'stopped': false, 'reason': 'not_found'};
  }

  Future<Map<String, dynamic>> _stopAll() async {
    final count = _servers.length;
    for (final managed in _servers.values) {
      await managed.server.close(force: true);
    }
    _servers.clear();
    _routes.clear();
    return {'stopped': count};
  }

  Map<String, dynamic> _getServers() {
    return {
      'servers': _servers.values
          .map((s) => {
                'id': s.id,
                'port': s.server.port,
                'requestCount': s.requestCount,
                'hasStaticDir': s.staticDir != null,
                'routeCount': _routes[s.id]?.length ?? 0,
              })
          .toList(),
      'count': _servers.length,
    };
  }

  Map<String, dynamic> _getRequests(Map<String, dynamic> args) {
    final serverId = args['serverId'] as String;
    final managed = _servers[serverId];
    if (managed == null) {
      return {'found': false};
    }
    return {
      'found': true,
      'requestCount': managed.requestCount,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'stop':
      case 'getRequests':
        if (args['id'] is! String && args['serverId'] is! String) {
          return ValidationResult.invalid('id or serverId is required');
        }
        return ValidationResult.valid();
      case 'addRoute':
        if (args['serverId'] is! String) {
          return ValidationResult.invalid('serverId is required');
        }
        if (args['path'] is! String) {
          return ValidationResult.invalid('path is required');
        }
        return ValidationResult.valid();
      case 'serveDirectory':
        if (args['serverId'] is! String) {
          return ValidationResult.invalid('serverId is required');
        }
        if (args['directory'] is! String) {
          return ValidationResult.invalid('directory is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}

class _ManagedServer {
  final String id;
  final HttpServer server;
  final bool enableCors;
  String? staticDir;
  int requestCount = 0;

  _ManagedServer({
    required this.id,
    required this.server,
    this.enableCors = true,
  });
}

class _RouteHandler {
  final String method;
  final String path;
  final int statusCode;
  final String contentType;
  final dynamic responseBody;

  const _RouteHandler({
    required this.method,
    required this.path,
    this.statusCode = 200,
    this.contentType = 'application/json',
    this.responseBody,
  });
}
