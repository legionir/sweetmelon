import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class FilePickerPlugin extends Plugin {
  @override
  String get name => 'filePicker';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Pick files, images, videos from device';

  @override
  List<String> get supportedMethods => [
        'pickFiles',
        'pickImages',
        'pickVideos',
        'pickMedia',
        'pickDirectory',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'pickFiles':
        return _pickFiles(args);
      case 'pickImages':
        return _pickFiles({...args, 'type': 'image'});
      case 'pickVideos':
        return _pickFiles({...args, 'type': 'video'});
      case 'pickMedia':
        return _pickFiles({...args, 'type': 'media'});
      case 'pickDirectory':
        return _pickDirectory();
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _pickFiles(Map<String, dynamic> args) async {
    final allowMultiple = args['multiple'] as bool? ?? false;
    final typeStr = args['type'] as String? ?? 'any';
    final allowedExtensions = args['allowedExtensions'] != null
        ? List<String>.from(args['allowedExtensions'] as List)
        : null;
    final withData = args['withData'] as bool? ?? false;

    final fileType = _parseFileType(typeStr);

    try {
      final result = await fp.FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: allowedExtensions != null ? fp.FileType.custom : fileType,
        allowedExtensions: allowedExtensions,
        withData: withData,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        return {'picked': false, 'reason': 'cancelled', 'files': <dynamic>[]};
      }

      final files = <Map<String, dynamic>>[];

      for (final file in result.files) {
        final fileInfo = <String, dynamic>{
          'name': file.name,
          'size': file.size,
          'extension': file.extension,
          'path': file.path,
        };

        if (file.path != null) {
          final f = File(file.path!);
          if (await f.exists()) {
            final stat = await f.stat();
            fileInfo['modified'] = stat.modified.toIso8601String();
          }
        }

        files.add(fileInfo);
      }

      return {
        'picked': true,
        'files': files,
        'count': files.length,
      };
    } catch (e) {
      BridgeLogger.error('FilePicker', 'Pick error: $e');
      return {'picked': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _pickDirectory() async {
    try {
      final path = await fp.FilePicker.platform.getDirectoryPath();

      if (path == null) {
        return {'picked': false, 'reason': 'cancelled'};
      }

      return {
        'picked': true,
        'path': path,
      };
    } catch (e) {
      return {'picked': false, 'error': e.toString()};
    }
  }

  fp.FileType _parseFileType(String type) {
    switch (type) {
      case 'image':
        return fp.FileType.image;
      case 'video':
        return fp.FileType.video;
      case 'audio':
        return fp.FileType.audio;
      case 'media':
        return fp.FileType.media;
      case 'any':
      default:
        return fp.FileType.any;
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'pickFiles') {
      final ext = args['allowedExtensions'];
      if (ext != null && ext is! List) {
        return ValidationResult.invalid('allowedExtensions must be a list');
      }
    }
    return ValidationResult.valid();
  }
}
