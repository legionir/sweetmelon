import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class CacheControlPlugin extends Plugin {
  @override
  String get name => 'cacheControl';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'WebView cache control, clear, and preload plugin';

  @override
  List<String> get supportedMethods => [
        'clearWebViewCache',
        'clearAppCache',
        'getCacheSize',
        'clearAll',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'clearWebViewCache':
        return _clearWebViewCache();
      case 'clearAppCache':
        return _clearAppCache();
      case 'getCacheSize':
        return _getCacheSize();
      case 'clearAll':
        return _clearAll();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _clearWebViewCache() async {
    try {
      final controller = WebViewController();
      await controller.clearCache();
      await controller.clearLocalStorage();

      BridgeLogger.info('CacheControl', 'WebView cache cleared');

      return {'cleared': true, 'type': 'webview'};
    } catch (e) {
      BridgeLogger.error('CacheControl', 'Failed to clear WebView cache: $e');
      return {'cleared': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _clearAppCache() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      int filesDeleted = 0;
      int bytesFreed = 0;

      if (await cacheDir.exists()) {
        final entities = await cacheDir.list(recursive: true).toList();

        for (final entity in entities) {
          if (entity is File) {
            final stat = await entity.stat();
            bytesFreed += stat.size;
            await entity.delete();
            filesDeleted++;
          }
        }
      }

      BridgeLogger.info(
        'CacheControl',
        'App cache cleared: $filesDeleted files, ${_formatBytes(bytesFreed)}',
      );

      return {
        'cleared': true,
        'type': 'appCache',
        'filesDeleted': filesDeleted,
        'bytesFreed': bytesFreed,
        'bytesFreedFormatted': _formatBytes(bytesFreed),
      };
    } catch (e) {
      BridgeLogger.error('CacheControl', 'Failed to clear app cache: $e');
      return {'cleared': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getCacheSize() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      int totalBytes = 0;
      int fileCount = 0;

      if (await cacheDir.exists()) {
        final entities = await cacheDir.list(recursive: true).toList();

        for (final entity in entities) {
          if (entity is File) {
            final stat = await entity.stat();
            totalBytes += stat.size;
            fileCount++;
          }
        }
      }

      final tempDir = await getTemporaryDirectory();
      int tempBytes = 0;
      int tempCount = 0;

      if (await tempDir.exists()) {
        final entities = await tempDir.list(recursive: true).toList();

        for (final entity in entities) {
          if (entity is File) {
            final stat = await entity.stat();
            tempBytes += stat.size;
            tempCount++;
          }
        }
      }

      return {
        'cache': {
          'bytes': totalBytes,
          'formatted': _formatBytes(totalBytes),
          'files': fileCount,
        },
        'temp': {
          'bytes': tempBytes,
          'formatted': _formatBytes(tempBytes),
          'files': tempCount,
        },
        'total': {
          'bytes': totalBytes + tempBytes,
          'formatted': _formatBytes(totalBytes + tempBytes),
          'files': fileCount + tempCount,
        },
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _clearAll() async {
    final webView = await _clearWebViewCache();
    final appCache = await _clearAppCache();

    // Clear temp dir too
    int tempFreed = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final entities = await tempDir.list(recursive: true).toList();
        for (final entity in entities) {
          if (entity is File) {
            final stat = await entity.stat();
            tempFreed += stat.size;
            await entity.delete();
          }
        }
      }
    } catch (_) {}

    return {
      'cleared': true,
      'webView': webView['cleared'] ?? false,
      'appCache': appCache,
      'tempBytesFreed': tempFreed,
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)}MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)}GB';
  }
}
