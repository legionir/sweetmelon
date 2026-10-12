import 'dart:async';
import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class DocumentScannerPlugin extends Plugin {
  @override
  String get name => 'documentScanner';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Document scanning with auto-crop';

  @override
  List<String> get requiredPermissions => ['camera'];

  @override
  List<String> get supportedMethods => [
        'scan',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'scan':
        return _scan(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _scan(Map<String, dynamic> args) async {
    final maxPages = (args['maxPages'] as num?)?.toInt() ?? 1;
    final isGalleryImportAllowed = args['allowGallery'] as bool? ?? false;

    try {
      final images = await CunningDocumentScanner.getPictures(
        noOfPages: maxPages,
        isGalleryImportAllowed: isGalleryImportAllowed,
      );

      if (images == null || images.isEmpty) {
        return {'scanned': false, 'reason': 'cancelled', 'pages': <dynamic>[]};
      }

      final pages = <Map<String, dynamic>>[];

      for (int i = 0; i < images.length; i++) {
        final path = images[i];
        final file = File(path);

        if (await file.exists()) {
          final stat = await file.stat();
          pages.add({
            'page': i + 1,
            'path': path,
            'size': stat.size,
          });
        }
      }

      BridgeLogger.info(
        'DocumentScanner',
        'Scanned ${pages.length} pages',
      );

      return {
        'scanned': true,
        'pages': pages,
        'count': pages.length,
      };
    } catch (e) {
      BridgeLogger.error('DocumentScanner', 'Scan failed: $e');
      return {'scanned': false, 'error': e.toString()};
    }
  }
}
