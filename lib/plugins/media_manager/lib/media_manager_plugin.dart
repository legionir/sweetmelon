import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path/path.dart' as p;
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class MediaManagerPlugin extends Plugin {
  @override
  String get name => 'mediaManager';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Save media to gallery, manage albums';

  @override
  List<String> get supportedMethods => [
        'saveImageToGallery',
        'saveVideoToGallery',
        'saveFileToGallery',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'saveImageToGallery':
        return _saveImageToGallery(args);
      case 'saveVideoToGallery':
        return _saveVideoToGallery(args);
      case 'saveFileToGallery':
        return _saveFileToGallery(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _saveImageToGallery(
    Map<String, dynamic> args,
  ) async {
    final path = args['path'] as String;
    final quality = (args['quality'] as num?)?.toInt() ?? 100;

    final file = File(path);
    if (!await file.exists()) {
      return {'saved': false, 'reason': 'file_not_found'};
    }

    try {
      final bytes = await file.readAsBytes();
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(bytes),
        quality: quality,
        name: p.basenameWithoutExtension(path),
      );

      final success = result['isSuccess'] == true;

      BridgeLogger.info(
        'MediaManager',
        'Image saved to gallery: $success',
      );

      return {
        'saved': success,
        'filePath': result['filePath'],
      };
    } catch (e) {
      return {'saved': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _saveVideoToGallery(
    Map<String, dynamic> args,
  ) async {
    final path = args['path'] as String;

    final file = File(path);
    if (!await file.exists()) {
      return {'saved': false, 'reason': 'file_not_found'};
    }

    try {
      final result = await ImageGallerySaverPlus.saveFile(
        path,
        name: p.basenameWithoutExtension(path),
      );

      final success = result['isSuccess'] == true;

      return {
        'saved': success,
        'filePath': result['filePath'],
      };
    } catch (e) {
      return {'saved': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _saveFileToGallery(
    Map<String, dynamic> args,
  ) async {
    final path = args['path'] as String;

    final file = File(path);
    if (!await file.exists()) {
      return {'saved': false, 'reason': 'file_not_found'};
    }

    try {
      final result = await ImageGallerySaverPlus.saveFile(path);
      final success = result['isSuccess'] == true;

      return {
        'saved': success,
        'filePath': result['filePath'],
      };
    } catch (e) {
      return {'saved': false, 'error': e.toString()};
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'saveImageToGallery':
      case 'saveVideoToGallery':
      case 'saveFileToGallery':
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
