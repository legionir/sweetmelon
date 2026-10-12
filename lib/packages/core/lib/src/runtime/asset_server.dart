import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';

/// تنظیمات مسیر assets و www
class AssetServerConfig {
  /// مسیر ثابت index.html: assets/www/index.html
  static const String wwwRoot = 'assets/www';

  /// مسیر index.html نسبت به wwwRoot
  final String indexFile;

  /// پسوندهای مجاز برای serve کردن
  final Set<String> allowedExtensions;

  /// حداکثر سایز فایل (bytes)
  final int maxFileSize;

  const AssetServerConfig({
    this.indexFile = 'index.html',
    this.allowedExtensions = const {
      '.html',
      '.htm',
      '.css',
      '.js',
      '.json',
      '.xml',
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.svg',
      '.ico',
      '.webp',
      '.woff',
      '.woff2',
      '.ttf',
      '.eot',
      '.otf',
      '.mp3',
      '.mp4',
      '.wav',
      '.ogg',
      '.webm',
      '.map',
      '.txt',
      '.csv',
      '.pdf',
    },
    this.maxFileSize = 50 * 1024 * 1024, // 50MB
  });
}

/// Local HTTP server for serving asset files to WebView
class AssetServer {
  final AssetServerConfig config;
  HttpServer? _server;
  String? _extractedPath;
  int? _port;
  bool _running = false;

  AssetServer({required this.config});

  /// پورت سرور
  int get port => _port ?? 0;

  /// آدرس پایه سرور
  String get baseUrl => 'http://localhost:$_port';

  /// آیا سرور اجرا می‌شود
  bool get isRunning => _running;

  /// آدرس index.html
  String get indexUrl => '$baseUrl/${config.indexFile}';

  /// شروع سرور: assets را extract و HTTP server را start کن
  Future<String> start() async {
    if (_running) return indexUrl;

    // مرحله ۱: extract کردن assets/www به filesystem
    _extractedPath = await _extractAssets();

    // مرحله ۲: شروع HTTP server
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    _running = true;

    BridgeLogger.info('AssetServer', 'Started on port $_port');
    BridgeLogger.info('AssetServer', 'Serving from: $_extractedPath');
    BridgeLogger.info('AssetServer', 'Index URL: $indexUrl');

    // Handle requests
    _server!.listen(
      _handleRequest,
      onError: (error) {
        BridgeLogger.error('AssetServer', 'Server error: $error');
      },
    );

    return indexUrl;
  }

  /// Extract assets/www/* to app's temporary directory
  Future<String> _extractAssets() async {
    final tempDir = await getTemporaryDirectory();
    final wwwDir = Directory('${tempDir.path}/www_server');

    // پاک کردن دایرکتوری قبلی
    if (await wwwDir.exists()) {
      await wwwDir.delete(recursive: true);
    }
    await wwwDir.create(recursive: true);

    // خواندن manifest برای پیدا کردن همه assets
    //
    // از نسخه‌های جدید Flutter فایل AssetManifest.json دیگر در bundle وجود
    // ندارد و جای خود را به AssetManifest.bin داده است؛ بنابراین به‌جای
    // خواندن مستقیم JSON، از API رسمی AssetManifest استفاده می‌کنیم که هر دو
    // قالب را پشتیبانی می‌کند.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    int fileCount = 0;

    for (final assetKey in manifest.listAssets()) {
      // فقط فایل‌هایی که در assets/www/ هستند
      if (!assetKey.startsWith(AssetServerConfig.wwwRoot)) continue;

      // مسیر نسبی بعد از assets/www/
      final relativePath =
          assetKey.substring('${AssetServerConfig.wwwRoot}/'.length);

      if (relativePath.isEmpty) continue;

      // بررسی پسوند مجاز
      final ext = _getExtension(relativePath);
      if (!config.allowedExtensions.contains(ext)) {
        BridgeLogger.warn(
          'AssetServer',
          'Skipping disallowed file type: $relativePath ($ext)',
        );
        continue;
      }

      try {
        final data = await rootBundle.load(assetKey);
        final targetFile = File('${wwwDir.path}/$relativePath');

        // ساخت پوشه‌های والد
        await targetFile.parent.create(recursive: true);

        // نوشتن فایل
        await targetFile.writeAsBytes(
          data.buffer.asUint8List(),
          flush: true,
        );
        fileCount++;
      } catch (e) {
        BridgeLogger.error(
          'AssetServer',
          'Failed to extract: $relativePath — $e',
        );
      }
    }

    BridgeLogger.info(
      'AssetServer',
      'Extracted $fileCount files to ${wwwDir.path}',
    );

    return wwwDir.path;
  }

  /// Handle incoming HTTP request
  Future<void> _handleRequest(HttpRequest request) async {
    if (_extractedPath == null) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..write('Server not ready')
        ..close();
      return;
    }

    // CORS headers
    request.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
      ..set('Access-Control-Allow-Headers', '*')
      ..set('Cache-Control', 'no-cache');

    // OPTIONS request
    if (request.method == 'OPTIONS') {
      request.response
        ..statusCode = HttpStatus.ok
        ..close();
      return;
    }

    // فقط GET و HEAD
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..write('Method not allowed')
        ..close();
      return;
    }

    var requestPath = Uri.decodeFull(request.uri.path);
    if (requestPath.startsWith('/')) {
      requestPath = requestPath.substring(1);
    }

    // مسیر خالی → index.html
    if (requestPath.isEmpty) {
      requestPath = config.indexFile;
    }

    // جلوگیری از path traversal
    if (requestPath.contains('..') || requestPath.contains('~')) {
      BridgeLogger.warn(
        'AssetServer',
        'Path traversal attempt blocked: $requestPath',
      );
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('Forbidden')
        ..close();
      return;
    }

    final filePath = '$_extractedPath/$requestPath';
    final file = File(filePath);

    // بررسی وجود فایل
    if (!await file.exists()) {
      // SPA fallback: اگه فایل نیست، index.html رو برگردون
      final indexPath = '$_extractedPath/${config.indexFile}';
      final indexFile = File(indexPath);

      if (await indexFile.exists()) {
        BridgeLogger.debug(
          'AssetServer',
          'SPA fallback for: $requestPath → ${config.indexFile}',
        );
        await _serveFile(request, indexFile, 'text/html');
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not Found: $requestPath')
          ..close();
      }
      return;
    }

    // بررسی سایز
    final stat = await file.stat();
    if (stat.size > config.maxFileSize) {
      request.response
        ..statusCode = HttpStatus.requestEntityTooLarge
        ..write('File too large')
        ..close();
      return;
    }

    // تعیین MIME type
    final mimeType = _getMimeType(requestPath);

    await _serveFile(request, file, mimeType);
  }

  Future<void> _serveFile(
    HttpRequest request,
    File file,
    String mimeType,
  ) async {
    try {
      final bytes = await file.readAsBytes();

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.parse(mimeType)
        ..contentLength = bytes.length;

      if (request.method == 'GET') {
        request.response.add(bytes);
      }

      await request.response.close();
    } catch (e) {
      BridgeLogger.error('AssetServer', 'Error serving file: $e');
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Internal Server Error')
        ..close();
    }
  }

  String _getMimeType(String path) {
    final mimeType = lookupMimeType(path);
    if (mimeType != null) return mimeType;

    // Fallback for common types
    final ext = _getExtension(path);
    switch (ext) {
      case '.js':
        return 'application/javascript';
      case '.mjs':
        return 'application/javascript';
      case '.css':
        return 'text/css';
      case '.html':
      case '.htm':
        return 'text/html';
      case '.json':
        return 'application/json';
      case '.svg':
        return 'image/svg+xml';
      case '.woff':
        return 'font/woff';
      case '.woff2':
        return 'font/woff2';
      case '.ttf':
        return 'font/ttf';
      case '.map':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }

  String _getExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return '';
    return path.substring(lastDot).toLowerCase();
  }

  /// متوقف کردن سرور
  Future<void> stop() async {
    if (!_running) return;

    await _server?.close(force: true);
    _server = null;
    _port = null;
    _running = false;

    // پاک کردن فایل‌های extract شده
    if (_extractedPath != null) {
      try {
        final dir = Directory(_extractedPath!);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        BridgeLogger.warn('AssetServer', 'Cleanup error: $e');
      }
      _extractedPath = null;
    }

    BridgeLogger.info('AssetServer', 'Server stopped');
  }
}
