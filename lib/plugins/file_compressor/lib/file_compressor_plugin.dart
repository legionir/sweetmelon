import 'dart:async';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class FileCompressorPlugin extends Plugin {
  @override
  String get name => 'fileCompressor';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Image compression plugin (JPEG, PNG, WebP)';

  @override
  List<String> get supportedMethods => [
        'compressImage',
        'compressToWebP',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'compressImage':
        return _compressImage(args);
      case 'compressToWebP':
        return _compressImage({...args, 'format': 'webp'});
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'supportedFormats': ['jpeg', 'png', 'webp'],
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _compressImage(Map<String, dynamic> args) async {
    final inputPath = args['path'] as String;
    final quality = (args['quality'] as num?)?.toInt() ?? 80;
    final maxWidth = (args['maxWidth'] as num?)?.toInt();
    final maxHeight = (args['maxHeight'] as num?)?.toInt();
    final format = args['format'] as String? ?? 'jpeg';
    final keepExif = args['keepExif'] as bool? ?? false;

    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      return {'compressed': false, 'reason': 'file_not_found'};
    }

    final originalSize = await inputFile.length();

    final tempDir = await getTemporaryDirectory();
    final ext =
        format == 'webp' ? '.webp' : (format == 'png' ? '.png' : '.jpg');
    final outputPath = p.join(
      tempDir.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}$ext',
    );

    final compressFormat = format == 'webp'
        ? CompressFormat.webp
        : (format == 'png' ? CompressFormat.png : CompressFormat.jpeg);

    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        inputPath,
        outputPath,
        quality: quality,
        minWidth: maxWidth ?? 1920,
        minHeight: maxHeight ?? 1080,
        format: compressFormat,
        keepExif: keepExif,
      );

      if (result == null) {
        return {'compressed': false, 'reason': 'compression_failed'};
      }

      final compressedSize = await result.length();
      final savings = originalSize > 0
          ? ((1 - compressedSize / originalSize) * 100).round()
          : 0;

      BridgeLogger.info(
        'FileCompressor',
        'Compressed: ${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)} ($savings% saved)',
      );

      return {
        'compressed': true,
        'inputPath': inputPath,
        'outputPath': result.path,
        'originalSize': originalSize,
        'compressedSize': compressedSize,
        'savings': savings,
        'format': format,
        'quality': quality,
      };
    } catch (e) {
      BridgeLogger.error('FileCompressor', 'Compression error: $e');
      return {'compressed': false, 'error': e.toString()};
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'compressImage' || method == 'compressToWebP') {
      final path = args['path'];
      if (path is! String || path.isEmpty) {
        return ValidationResult.invalid('path is required');
      }
      final quality = args['quality'];
      if (quality != null &&
          (quality is! num || quality < 1 || quality > 100)) {
        return ValidationResult.invalid('quality must be 1-100');
      }
    }
    return ValidationResult.valid();
  }
}
