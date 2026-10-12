import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class ZipPlugin extends Plugin {
  @override
  String get name => 'zip';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Zip and unzip files plugin';

  @override
  List<String> get supportedMethods => [
        'zip',
        'unzip',
        'listContents',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'zip':
        return _zip(args);
      case 'unzip':
        return _unzip(args);
      case 'listContents':
        return _listContents(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _zip(Map<String, dynamic> args) async {
    final inputPaths = List<String>.from(args['paths'] as List);
    final outputPath = args['outputPath'] as String?;

    final archive = Archive();
    int totalSize = 0;

    for (final path in inputPaths) {
      final entity = FileSystemEntity.typeSync(path);

      if (entity == FileSystemEntityType.file) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          totalSize += bytes.length;
          archive.addFile(
            ArchiveFile(p.basename(path), bytes.length, bytes),
          );
        }
      } else if (entity == FileSystemEntityType.directory) {
        final dir = Directory(path);
        final files = await dir.list(recursive: true).toList();

        for (final f in files) {
          if (f is File) {
            final bytes = await f.readAsBytes();
            final relativePath = p.relative(f.path, from: path);
            totalSize += bytes.length;
            archive.addFile(
              ArchiveFile(relativePath, bytes.length, bytes),
            );
          }
        }
      }
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      return {'zipped': false, 'reason': 'encoding_failed'};
    }

    final output = outputPath ??
        p.join(
          (await getTemporaryDirectory()).path,
          'archive_${DateTime.now().millisecondsSinceEpoch}.zip',
        );

    final outputFile = File(output);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(encoded);

    final compressedSize = encoded.length;
    final ratio =
        totalSize > 0 ? ((1 - compressedSize / totalSize) * 100).round() : 0;

    BridgeLogger.info(
      'Zip',
      'Created: $output (${archive.files.length} files, $ratio% compression)',
    );

    return {
      'zipped': true,
      'outputPath': output,
      'fileCount': archive.files.length,
      'originalSize': totalSize,
      'compressedSize': compressedSize,
      'compressionRatio': ratio,
    };
  }

  Future<Map<String, dynamic>> _unzip(Map<String, dynamic> args) async {
    final zipPath = args['path'] as String;
    final outputDir = args['outputDir'] as String?;

    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      return {'unzipped': false, 'reason': 'file_not_found'};
    }

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final targetDir = outputDir ??
        p.join(
          (await getTemporaryDirectory()).path,
          'unzipped_${DateTime.now().millisecondsSinceEpoch}',
        );

    int fileCount = 0;
    int totalSize = 0;

    for (final file in archive) {
      final filePath = p.join(targetDir, file.name);

      // path traversal protection
      if (!p.normalize(filePath).startsWith(p.normalize(targetDir))) {
        BridgeLogger.warn('Zip', 'Skipping unsafe path: ${file.name}');
        continue;
      }

      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
        totalSize += file.size;
        fileCount++;
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }

    BridgeLogger.info(
      'Zip',
      'Extracted: $fileCount files to $targetDir',
    );

    return {
      'unzipped': true,
      'outputDir': targetDir,
      'fileCount': fileCount,
      'totalSize': totalSize,
    };
  }

  Future<Map<String, dynamic>> _listContents(Map<String, dynamic> args) async {
    final zipPath = args['path'] as String;

    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      return {'files': <dynamic>[], 'error': 'file_not_found'};
    }

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final files = archive.files
        .map((f) => {
              'name': f.name,
              'size': f.size,
              'isFile': f.isFile,
              'isDirectory': !f.isFile,
            })
        .toList();

    return {
      'files': files,
      'count': files.length,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'zip':
        final paths = args['paths'];
        if (paths is! List || paths.isEmpty) {
          return ValidationResult.invalid('paths (list) is required');
        }
        return ValidationResult.valid();

      case 'unzip':
      case 'listContents':
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
