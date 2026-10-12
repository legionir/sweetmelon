import 'dart:async';
import 'dart:io';

import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class FileOpenerPlugin extends Plugin {
  @override
  String get name => 'fileOpener';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Open files with system default app';

  @override
  List<String> get supportedMethods => [
        'open',
        'canOpen',
        'getMimeType',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'open':
        return _open(args);
      case 'canOpen':
        return _canOpen(args);
      case 'getMimeType':
        return _getMimeType(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _open(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final mimeType = args['mimeType'] as String?;

    final file = File(path);
    if (!await file.exists()) {
      return {'opened': false, 'reason': 'file_not_found', 'path': path};
    }

    final resolvedMime =
        mimeType ?? lookupMimeType(path) ?? 'application/octet-stream';

    try {
      // Android: استفاده از intent
      final uri = Uri.file(path);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      BridgeLogger.info('FileOpener', 'Opening: $path ($resolvedMime)');

      return {
        'opened': launched,
        'path': path,
        'mimeType': resolvedMime,
      };
    } catch (e) {
      BridgeLogger.error('FileOpener', 'Open failed: $e');
      return {
        'opened': false,
        'error': e.toString(),
        'path': path,
      };
    }
  }

  Future<Map<String, dynamic>> _canOpen(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final file = File(path);

    if (!await file.exists()) {
      return {'canOpen': false, 'reason': 'file_not_found'};
    }

    try {
      final uri = Uri.file(path);
      final can = await canLaunchUrl(uri);
      return {'canOpen': can, 'path': path};
    } catch (e) {
      return {'canOpen': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _getMimeType(Map<String, dynamic> args) {
    final path = args['path'] as String;
    final mime = lookupMimeType(path) ?? 'application/octet-stream';
    return {'path': path, 'mimeType': mime};
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'open':
      case 'canOpen':
      case 'getMimeType':
        final path = args['path'];
        if (path is! String || path.isEmpty) {
          return ValidationResult.invalid('path is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
