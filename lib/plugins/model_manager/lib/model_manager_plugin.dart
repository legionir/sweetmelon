import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:path/path.dart' as p;
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef ModelEventEmitter = Future<void> Function(String event, dynamic data);

/// A file the user picked.
class PickedModelFile {
  const PickedModelFile({required this.name, required this.path});
  final String name;
  final String path;
}

/// Opens the system file picker. Replaced in tests.
typedef ModelFilePicker = Future<List<PickedModelFile>?> Function(
  List<String>? extensions,
);

Future<List<PickedModelFile>?> _systemPicker(List<String>? extensions) async {
  final result = await fp.FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: extensions == null ? fp.FileType.any : fp.FileType.custom,
    allowedExtensions: extensions,
    withData: false,
    withReadStream: false,
  );
  if (result == null || result.files.isEmpty) return null;
  return [
    for (final file in result.files)
      if (file.path != null) PickedModelFile(name: file.name, path: file.path!),
  ];
}

/// Keeps AI models (language, speech recognition, speech synthesis...) in one
/// folder of the app and imports them from the user's own files.
///
/// A model is a folder; see [ModelStore]. The user picks the files (or an
/// archive: `.zip`, `.tar.gz`, `.tar.bz2`, `.tar.xz`), the plugin moves them
/// into the folder and the plugins that run models read them from there.
class ModelManagerPlugin extends Plugin {
  ModelManagerPlugin({
    this.eventEmitter,
    ModelStore? store,
    ModelFilePicker? picker,
  })  : _store = store,
        _picker = picker ?? _systemPicker;

  final ModelEventEmitter? eventEmitter;
  final ModelFilePicker _picker;
  ModelStore? _store;

  @override
  String get name => 'modelManager';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'AI model files: import from the device, list, remove';

  // Importing needs no permission: the system picker hands over the files.
  @override
  List<String> get requiredPermissions => const [];

  @override
  List<String> get supportedMethods => [
        'import',
        'list',
        'get',
        'remove',
        'rename',
        'getInfo',
      ];

  Future<ModelStore> _getStore() async => _store ??= await ModelStore.forApp();

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'import':
        return _import(args);
      case 'list':
        return _list(args);
      case 'get':
        return _get(args);
      case 'remove':
        return _remove(args);
      case 'rename':
        return _rename(args);
      case 'getInfo':
        return _info();
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<void> _emit(String event, Map<String, dynamic> data) async {
    await eventEmitter?.call(event, data);
  }

  /// Lets the user pick files (or an archive) and stores them as one model.
  Future<Map<String, dynamic>> _import(Map<String, dynamic> args) async {
    final store = await _getStore();
    final kind = args['kind'] as String;
    final extract = args['extract'] as bool? ?? true;
    final extensions = (args['extensions'] as List?)
        ?.map((e) => e.toString().replaceFirst('.', '').toLowerCase())
        .toList();

    final picked = await _picker(extensions);
    if (picked == null || picked.isEmpty) {
      return {'imported': false, 'reason': 'cancelled'};
    }

    final requestedName = (args['name'] as String?)?.trim();
    final name = requestedName != null && requestedName.isNotEmpty
        ? requestedName
        : _defaultName(picked.first.name);

    final entry = await store.create(kind: kind, name: name);
    final dir = Directory(entry.dir);
    await _emit('modelManager.progress',
        {'id': entry.id, 'stage': 'start', 'files': picked.length});

    try {
      var index = 0;
      for (final file in picked) {
        index++;
        await _emit('modelManager.progress', {
          'id': entry.id,
          'stage': _isArchive(file.name) && extract ? 'extracting' : 'moving',
          'file': file.name,
          'index': index,
          'files': picked.length,
        });
        if (extract && _isArchive(file.name)) {
          await _extract(file.path, dir.path);
          await _deleteQuietly(file.path);
        } else {
          await _moveInto(file, dir);
        }
      }
      await _flattenSingleRoot(dir);
      // The archive decoder swallows some errors: an unreadable archive would
      // otherwise end up as an empty model.
      if (await _isEmpty(dir)) {
        throw StateError('Nothing could be read from the picked files');
      }
    } catch (_) {
      await _deleteDirQuietly(dir);
      rethrow;
    }

    final stored = (await store.get(entry.id))!;
    await _emit('modelManager.progress', {'id': entry.id, 'stage': 'done'});
    return {'imported': true, 'model': stored.toJson()};
  }

  Future<Map<String, dynamic>> _list(Map<String, dynamic> args) async {
    final store = await _getStore();
    final models = await store.list(kind: args['kind'] as String?);
    return {'models': models.map((m) => m.toJson()).toList()};
  }

  Future<Map<String, dynamic>> _get(Map<String, dynamic> args) async {
    final store = await _getStore();
    final model = await store.get(args['id'] as String);
    if (model == null) return {'found': false};
    return {'found': true, 'model': model.toJson()};
  }

  Future<Map<String, dynamic>> _remove(Map<String, dynamic> args) async {
    final store = await _getStore();
    await store.remove(args['id'] as String);
    return {'removed': true};
  }

  Future<Map<String, dynamic>> _rename(Map<String, dynamic> args) async {
    final store = await _getStore();
    final model = await store.rename(
      args['id'] as String,
      args['name'] as String,
    );
    return {'model': model.toJson()};
  }

  Future<Map<String, dynamic>> _info() async {
    final store = await _getStore();
    final models = await store.list();
    return {
      'name': name,
      'version': version,
      'root': store.root.path,
      'count': models.length,
      'sizeBytes': models.fold<int>(0, (sum, m) => sum + m.sizeBytes),
    };
  }

  /// Moves a picked file into the model folder. The picker already copied it
  /// into the app's cache, which is on the same storage as the models folder,
  /// so the move is instant even for a multi-gigabyte model.
  Future<void> _moveInto(PickedModelFile file, Directory dir) async {
    final fileName = _safeName(file.name);
    final target = p.join(dir.path, fileName);
    final source = File(file.path);
    try {
      await source.rename(target);
    } on FileSystemException {
      // Another storage volume: copy, then remove the original.
      await source.copy(target);
      await _deleteQuietly(file.path);
    }
  }

  Future<void> _extract(String archivePath, String outputDir) async {
    await Isolate.run(() => extractFileToDisk(archivePath, outputDir));
  }

  /// Archives usually hold one folder (`vits-piper-xx/...`). Move its contents
  /// up, so the files are at the top of the model folder.
  Future<void> _flattenSingleRoot(Directory dir) async {
    final children = await dir
        .list(followLinks: false)
        .where((e) => !p.basename(e.path).startsWith('.'))
        .toList();
    if (children.length != 1 || children.single is! Directory) return;

    final root = children.single as Directory;
    await for (final child in root.list(followLinks: false)) {
      await child.rename(p.join(dir.path, p.basename(child.path)));
    }
    await root.delete(recursive: true);
  }

  Future<bool> _isEmpty(Directory dir) async {
    await for (final entity in dir.list(followLinks: false)) {
      if (!p.basename(entity.path).startsWith('.')) return false;
    }
    return true;
  }

  static bool _isArchive(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.zip') ||
        lower.endsWith('.tar') ||
        lower.endsWith('.tar.gz') ||
        lower.endsWith('.tgz') ||
        lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tbz') ||
        lower.endsWith('.tar.xz') ||
        lower.endsWith('.txz');
  }

  static String _defaultName(String fileName) {
    var base = p.basename(fileName);
    for (final suffix in const ['.tar.gz', '.tar.bz2', '.tar.xz']) {
      if (base.toLowerCase().endsWith(suffix)) {
        return base.substring(0, base.length - suffix.length);
      }
    }
    return p.basenameWithoutExtension(base);
  }

  static String _safeName(String name) {
    final base = p.basename(name.replaceAll('\\', '/'));
    if (base.isEmpty || base == '.' || base == '..' || base.startsWith('.')) {
      throw ArgumentError('Invalid file name: $name');
    }
    return base;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      /* already gone */
    }
  }

  Future<void> _deleteDirQuietly(Directory dir) async {
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      /* already gone */
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'import':
        final kind = args['kind'];
        if (kind is! String || !modelKindPattern.hasMatch(kind)) {
          return ValidationResult.invalid(
              'kind is required: lowercase letters, digits and _ (for example "llm")');
        }
        final extensions = args['extensions'];
        if (extensions != null && extensions is! List) {
          return ValidationResult.invalid('extensions must be a list');
        }
        return ValidationResult.valid();
      case 'list':
        final kind = args['kind'];
        if (kind != null &&
            (kind is! String || !modelKindPattern.hasMatch(kind))) {
          return ValidationResult.invalid('kind must be a valid model kind');
        }
        return ValidationResult.valid();
      case 'get':
      case 'remove':
      case 'rename':
        final id = args['id'];
        if (id is! String || !modelIdPattern.hasMatch(id)) {
          return ValidationResult.invalid('id is required');
        }
        if (method == 'rename' &&
            (args['name'] is! String ||
                (args['name'] as String).trim().isEmpty)) {
          return ValidationResult.invalid('name is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
