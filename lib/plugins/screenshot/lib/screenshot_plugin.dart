import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:sweetmelon/plugins/qr_scanner/lib/qr_scanner_plugin.dart';

class ScreenshotPlugin extends Plugin {
  @override
  String get name => 'screenshot';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Capture screenshots of the current view';

  @override
  List<String> get supportedMethods => [
        'capture',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'capture':
        return _capture(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _capture(Map<String, dynamic> args) async {
    final format = args['format'] as String? ?? 'png';
    final fileName = args['fileName'] as String? ??
        'screenshot_${DateTime.now().millisecondsSinceEpoch}';
    final baseDir = args['baseDir'] as String? ?? 'temporary';

    try {
      final context = QrScannerPlugin.navigatorKey?.currentContext;
      if (context == null) {
        return {'captured': false, 'reason': 'no_context'};
      }

      final renderObject = context.findRenderObject();
      if (renderObject == null || renderObject is! RenderRepaintBoundary) {
        return {'captured': false, 'reason': 'no_render_object'};
      }

      final boundary = renderObject;
      final pixelRatio =
          ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(
        format: format == 'jpg' || format == 'jpeg'
            ? ui.ImageByteFormat.rawRgba
            : ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        return {'captured': false, 'reason': 'byte_conversion_failed'};
      }

      final ext = format == 'jpg' || format == 'jpeg' ? '.jpg' : '.png';
      final dir = await _resolveDir(baseDir);
      final screenshotDir = Directory(p.join(dir.path, 'screenshots'));
      await screenshotDir.create(recursive: true);

      final filePath = p.join(screenshotDir.path, '$fileName$ext');
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final stat = await file.stat();

      BridgeLogger.info('Screenshot', 'Captured: $filePath');

      return {
        'captured': true,
        'path': filePath,
        'fileName': '$fileName$ext',
        'size': stat.size,
        'width': image.width,
        'height': image.height,
        'format': format,
      };
    } catch (e) {
      BridgeLogger.error('Screenshot', 'Capture failed: $e');
      return {'captured': false, 'error': e.toString()};
    }
  }

  Future<Directory> _resolveDir(String baseDir) async {
    switch (baseDir) {
      case 'documents':
        return getApplicationDocumentsDirectory();
      case 'cache':
        return getApplicationCacheDirectory();
      case 'temporary':
      default:
        return getTemporaryDirectory();
    }
  }
}
