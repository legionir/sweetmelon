import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where AI models live on the device, and how the AI plugins find them.
///
/// ```
/// <app support dir>/models/<kind>/<id>/   files of one model
///                                         .sweetmelon-model.json (name, kind)
/// ```
///
/// `kind` groups models by use (`llm`, `stt`, `tts`, ...). A model is a folder
/// because some are several files (a Whisper encoder, decoder and tokens; a
/// GGUF and its multimodal projector; a TTS voice with its data directory).
///
/// The plugins that run models only accept paths inside this folder
/// ([ModelStore.requireInside]), so a web page cannot make them open any other
/// file of the app.
final RegExp modelKindPattern = RegExp(r'^[a-z][a-z0-9_]{0,31}$');
final RegExp modelIdPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,79}$');

const String _metaFileName = '.sweetmelon-model.json';

/// One file inside a model folder.
class ModelFile {
  const ModelFile({required this.name, required this.path, required this.size});

  /// File name inside the model folder.
  final String name;

  /// Absolute path.
  final String path;
  final int size;

  Map<String, dynamic> toJson() => {'name': name, 'path': path, 'size': size};
}

/// A model folder and what is in it (top level only).
class ModelEntry {
  const ModelEntry({
    required this.id,
    required this.kind,
    required this.name,
    required this.dir,
    required this.files,
    required this.directories,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String name;

  /// Absolute path of the model folder.
  final String dir;
  final List<ModelFile> files;

  /// Names of the sub folders (for example `espeak-ng-data`).
  final List<String> directories;
  final DateTime createdAt;

  int get sizeBytes => files.fold(0, (sum, f) => sum + f.size);

  ModelFile? fileNamed(String name) {
    for (final file in files) {
      if (file.name == name) return file;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'name': name,
        'dir': dir,
        'files': files.map((f) => f.toJson()).toList(),
        'directories': directories,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.toIso8601String(),
      };
}

class ModelStore {
  ModelStore(this.root);

  /// The store of this app: `<app support dir>/models`.
  static Future<ModelStore> forApp() async {
    final support = await getApplicationSupportDirectory();
    return ModelStore(Directory(p.join(support.path, 'models')));
  }

  final Directory root;

  /// Lowercase, ASCII, safe as a folder name. Empty input gives `model`.
  static String slug(String name) {
    final lower = name.toLowerCase();
    final cleaned = lower
        .replaceAll(RegExp(r'\.[a-z0-9]{1,6}$'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final cut = cleaned.length > 48 ? cleaned.substring(0, 48) : cleaned;
    return cut.isEmpty ? 'model' : cut;
  }

  Directory dirOf(String kind, String id) {
    _checkKind(kind);
    _checkId(id);
    return Directory(p.join(root.path, kind, id));
  }

  /// Creates the folder of a new model. The id is the slug of [name] plus a
  /// short random suffix, so importing the same file twice never overwrites.
  Future<ModelEntry> create(
      {required String kind, required String name}) async {
    _checkKind(kind);
    final random = Random.secure();
    String id;
    Directory dir;
    do {
      final suffix = random.nextInt(0x1000000).toRadixString(36);
      id = '${slug(name)}-$suffix';
      dir = dirOf(kind, id);
    } while (await dir.exists());

    await dir.create(recursive: true);
    final entry = ModelEntry(
      id: id,
      kind: kind,
      name: name.trim().isEmpty ? id : name.trim(),
      dir: dir.path,
      files: const [],
      directories: const [],
      createdAt: DateTime.now(),
    );
    await File(p.join(dir.path, _metaFileName)).writeAsString(jsonEncode({
      'name': entry.name,
      'kind': kind,
      'createdAt': entry.createdAt.toIso8601String(),
    }));
    return (await get(id))!;
  }

  /// Every model, optionally of one kind, newest first.
  Future<List<ModelEntry>> list({String? kind}) async {
    if (kind != null) _checkKind(kind);
    if (!await root.exists()) return [];

    final result = <ModelEntry>[];
    await for (final kindDir in root.list(followLinks: false)) {
      if (kindDir is! Directory) continue;
      final kindName = p.basename(kindDir.path);
      if (!modelKindPattern.hasMatch(kindName)) continue;
      if (kind != null && kindName != kind) continue;

      await for (final modelDir in kindDir.list(followLinks: false)) {
        if (modelDir is! Directory) continue;
        final id = p.basename(modelDir.path);
        if (!modelIdPattern.hasMatch(id)) continue;
        final entry = await _read(kindName, id, modelDir);
        if (entry != null) result.add(entry);
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// A model by id, in any kind. Null when there is none.
  Future<ModelEntry?> get(String id) async {
    if (!modelIdPattern.hasMatch(id)) return null;
    if (!await root.exists()) return null;
    await for (final kindDir in root.list(followLinks: false)) {
      if (kindDir is! Directory) continue;
      final kindName = p.basename(kindDir.path);
      if (!modelKindPattern.hasMatch(kindName)) continue;
      final dir = Directory(p.join(kindDir.path, id));
      if (await dir.exists()) return _read(kindName, id, dir);
    }
    return null;
  }

  Future<void> remove(String id) async {
    final entry = await get(id);
    if (entry == null) throw ArgumentError('Model "$id" not found');
    await Directory(entry.dir).delete(recursive: true);
  }

  Future<ModelEntry> rename(String id, String name) async {
    final entry = await get(id);
    if (entry == null) throw ArgumentError('Model "$id" not found');
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('name must not be empty');
    await File(p.join(entry.dir, _metaFileName)).writeAsString(jsonEncode({
      'name': trimmed,
      'kind': entry.kind,
      'createdAt': entry.createdAt.toIso8601String(),
    }));
    return (await get(id))!;
  }

  /// True when [path] is inside the models folder (symbolic links resolved).
  bool contains(String path) {
    try {
      final base = root.existsSync()
          ? root.resolveSymbolicLinksSync()
          : p.canonicalize(root.path);
      final target =
          FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound
              ? p.canonicalize(path)
              : (File(path).existsSync()
                  ? File(path).resolveSymbolicLinksSync()
                  : Directory(path).resolveSymbolicLinksSync());
      return p.isWithin(base, target);
    } on FileSystemException {
      return false;
    }
  }

  /// [path] when it is inside the models folder, otherwise throws.
  String requireInside(String path) {
    if (path.isEmpty || !p.isAbsolute(path) || !contains(path)) {
      throw ArgumentError('Path is not inside the models folder: $path');
    }
    return path;
  }

  Future<ModelEntry?> _read(String kind, String id, Directory dir) async {
    var name = id;
    var createdAt = dir.statSync().modified;
    final meta = File(p.join(dir.path, _metaFileName));
    if (await meta.exists()) {
      try {
        final json = jsonDecode(await meta.readAsString()) as Map;
        name = (json['name'] as String?)?.trim().isNotEmpty == true
            ? (json['name'] as String).trim()
            : id;
        createdAt =
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? createdAt;
      } on FormatException {
        /* a damaged meta file: fall back to the folder name */
      }
    }

    final files = <ModelFile>[];
    final directories = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      final base = p.basename(entity.path);
      if (base.startsWith('.')) continue;
      if (entity is File) {
        files.add(ModelFile(
          name: base,
          path: entity.path,
          size: await entity.length(),
        ));
      } else if (entity is Directory) {
        directories.add(base);
      }
    }
    files.sort((a, b) => a.name.compareTo(b.name));
    directories.sort();

    return ModelEntry(
      id: id,
      kind: kind,
      name: name,
      dir: dir.path,
      files: files,
      directories: directories,
      createdAt: createdAt,
    );
  }

  static void _checkKind(String kind) {
    if (!modelKindPattern.hasMatch(kind)) {
      throw ArgumentError(
          'kind must be lowercase letters, digits and _ (starting with a letter): $kind');
    }
  }

  static void _checkId(String id) {
    if (!modelIdPattern.hasMatch(id)) {
      throw ArgumentError('Invalid model id: $id');
    }
  }
}
