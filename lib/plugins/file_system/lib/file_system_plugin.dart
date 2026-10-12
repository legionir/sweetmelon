import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class FileSystemPlugin extends Plugin {
  @override
  String get name => 'fileSystem';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Sandboxed internal file system plugin';

  @override
  List<String> get supportedMethods => [
        'getDirectories',
        'readFile',
        'writeFile',
        'deleteFile',
        'fileExists',
        'listFiles',
        'createDirectory',
        'deleteDirectory',
        'stat',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getDirectories':
        return _getDirectories();
      case 'readFile':
        return _readFile(args);
      case 'writeFile':
        return _writeFile(args);
      case 'deleteFile':
        return _deleteFile(args);
      case 'fileExists':
        return _fileExists(args);
      case 'listFiles':
        return _listFiles(args);
      case 'createDirectory':
        return _createDirectory(args);
      case 'deleteDirectory':
        return _deleteDirectory(args);
      case 'stat':
        return _stat(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'supportedBaseDirs': ['documents', 'cache', 'support', 'temporary'],
          'encodings': ['utf8', 'base64'],
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _getDirectories() async {
    final documents = await getApplicationDocumentsDirectory();
    final cache = await getApplicationCacheDirectory();
    final support = await getApplicationSupportDirectory();
    final temporary = await getTemporaryDirectory();

    return {
      'documents': documents.path,
      'cache': cache.path,
      'support': support.path,
      'temporary': temporary.path,
    };
  }

  Future<Map<String, dynamic>> _readFile(Map<String, dynamic> args) async {
    final file = await _resolveFile(
      args['path'] as String,
      baseDir: args['baseDir'] as String? ?? 'documents',
    );

    if (!await file.exists()) {
      throw FileSystemException('File not found', file.path);
    }

    final encoding = args['encoding'] as String? ?? 'utf8';

    if (encoding == 'base64') {
      final bytes = await file.readAsBytes();
      return {
        'path': file.path,
        'encoding': 'base64',
        'content': base64Encode(bytes),
      };
    }

    return {
      'path': file.path,
      'encoding': 'utf8',
      'content': await file.readAsString(),
    };
  }

  Future<Map<String, dynamic>> _writeFile(Map<String, dynamic> args) async {
    final file = await _resolveFile(
      args['path'] as String,
      baseDir: args['baseDir'] as String? ?? 'documents',
    );

    final content = args['content'] as String;
    final encoding = args['encoding'] as String? ?? 'utf8';
    final append = args['append'] as bool? ?? false;

    await file.parent.create(recursive: true);

    if (encoding == 'base64') {
      final bytes = base64Decode(content);
      if (append && await file.exists()) {
        await file.writeAsBytes(bytes, mode: FileMode.append);
      } else {
        await file.writeAsBytes(bytes, mode: FileMode.write);
      }
    } else {
      if (append) {
        await file.writeAsString(content, mode: FileMode.append);
      } else {
        await file.writeAsString(content, mode: FileMode.write);
      }
    }

    final stat = await file.stat();

    return {
      'success': true,
      'path': file.path,
      'size': stat.size,
      'modified': stat.modified.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _deleteFile(Map<String, dynamic> args) async {
    final file = await _resolveFile(
      args['path'] as String,
      baseDir: args['baseDir'] as String? ?? 'documents',
    );

    if (!await file.exists()) {
      return {'deleted': false, 'reason': 'not_found'};
    }

    await file.delete();

    return {'deleted': true};
  }

  Future<Map<String, dynamic>> _fileExists(Map<String, dynamic> args) async {
    final file = await _resolveFile(
      args['path'] as String,
      baseDir: args['baseDir'] as String? ?? 'documents',
    );

    return {'exists': await file.exists()};
  }

  Future<Map<String, dynamic>> _listFiles(Map<String, dynamic> args) async {
    final dir = await _resolveDirectory(
      args['path'] as String? ?? '',
      baseDir: args['baseDir'] as String? ?? 'documents',
    );

    if (!await dir.exists()) {
      return {'items': <dynamic>[]};
    }

    final recursive = args['recursive'] as bool? ?? false;
    final baseRoot =
        await _resolveBaseDir(args['baseDir'] as String? ?? 'documents');

    final entities = await dir
        .list(
          recursive: recursive,
          followLinks: false,
        )
        .toList();

    final items = <Map<String, dynamic>>[];

    for (final entity in entities) {
      final stat = await entity.stat();
      items.add({
        'name': p.basename(entity.path),
        'path': entity.path,
        'relativePath': p.relative(entity.path, from: baseRoot.path),
        'type': entity is Directory ? 'directory' : 'file',
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
      });
    }

    return {'items': items};
  }

  Future<Map<String, dynamic>> _createDirectory(
    Map<String, dynamic> args,
  ) async {
    final dir = await _resolveDirectory(
      args['path'] as String,
      baseDir: args['baseDir'] as String? ?? 'documents',
    );

    final recursive = args['recursive'] as bool? ?? true;
    await dir.create(recursive: recursive);

    return {
      'created': true,
      'path': dir.path,
    };
  }

  Future<Map<String, dynamic>> _deleteDirectory(
    Map<String, dynamic> args,
  ) async {
    final relativePath = args['path'] as String;
    if (relativePath.trim().isEmpty) {
      throw const FileSystemException(
        'Refusing to delete root base directory',
      );
    }

    final dir = await _resolveDirectory(
      relativePath,
      baseDir: args['baseDir'] as String? ?? 'documents',
    );

    if (!await dir.exists()) {
      return {'deleted': false, 'reason': 'not_found'};
    }

    final recursive = args['recursive'] as bool? ?? false;
    await dir.delete(recursive: recursive);

    return {'deleted': true};
  }

  Future<Map<String, dynamic>> _stat(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final type = args['type'] as String? ?? 'file';

    if (type == 'directory') {
      final dir = await _resolveDirectory(
        path,
        baseDir: args['baseDir'] as String? ?? 'documents',
      );

      if (!await dir.exists()) {
        return {'exists': false};
      }

      final stat = await dir.stat();
      return {
        'exists': true,
        'type': 'directory',
        'path': dir.path,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
      };
    }

    final file = await _resolveFile(
      path,
      baseDir: args['baseDir'] as String? ?? 'documents',
    );

    if (!await file.exists()) {
      return {'exists': false};
    }

    final stat = await file.stat();
    return {
      'exists': true,
      'type': 'file',
      'path': file.path,
      'size': stat.size,
      'modified': stat.modified.toIso8601String(),
    };
  }

  Future<Directory> _resolveBaseDir(String baseDir) async {
    switch (baseDir) {
      case 'documents':
        return getApplicationDocumentsDirectory();
      case 'cache':
        return getApplicationCacheDirectory();
      case 'support':
        return getApplicationSupportDirectory();
      case 'temporary':
      case 'temp':
        return getTemporaryDirectory();
      default:
        throw FileSystemException('Unsupported baseDir: $baseDir');
    }
  }

  Future<File> _resolveFile(
    String relativePath, {
    required String baseDir,
  }) async {
    final root = await _resolveBaseDir(baseDir);
    final safePath = _normalizeRelativePath(relativePath);
    return File(p.join(root.path, safePath));
  }

  Future<Directory> _resolveDirectory(
    String relativePath, {
    required String baseDir,
  }) async {
    final root = await _resolveBaseDir(baseDir);
    final safePath = _normalizeRelativePath(relativePath);
    return Directory(p.join(root.path, safePath));
  }

  String _normalizeRelativePath(String input) {
    final normalized = p.normalize(
      input.replaceAll('\\', '/').trim(),
    );

    if (normalized.isEmpty || normalized == '.') {
      return '';
    }

    if (p.isAbsolute(normalized) ||
        normalized.startsWith('..') ||
        normalized.contains('../') ||
        normalized == '..') {
      throw const FileSystemException(
        'Invalid path: path traversal detected',
      );
    }

    return normalized;
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'readFile':
      case 'deleteFile':
      case 'fileExists':
        return _validatePathRequired(args);

      case 'writeFile':
        final pathResult = _validatePathRequired(args);
        if (!pathResult.isValid) return pathResult;

        final content = args['content'];
        if (content is! String) {
          return ValidationResult.invalid(
            'content is required and must be a string',
          );
        }

        final encoding = args['encoding'];
        if (encoding != null && encoding != 'utf8' && encoding != 'base64') {
          return ValidationResult.invalid(
            'encoding must be "utf8" or "base64"',
          );
        }

        return ValidationResult.valid();

      case 'createDirectory':
      case 'deleteDirectory':
      case 'stat':
        return _validatePathRequired(args);

      default:
        return ValidationResult.valid();
    }
  }

  ValidationResult _validatePathRequired(Map<String, dynamic> args) {
    final path = args['path'];
    if (path is! String || path.isEmpty) {
      return ValidationResult.invalid(
        'path is required and must be a non-empty string',
      );
    }

    if (path.contains('..')) {
      return ValidationResult.invalid(
        'path cannot contain ".."',
      );
    }

    return ValidationResult.valid();
  }
}
