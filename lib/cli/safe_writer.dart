import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

enum ChangeKind { created, modified, deleted }

/// A file that [SafeWriter.commit] creates, changes or deletes.
class FileChange {
  const FileChange(this.path, this.kind);

  /// Path relative to the project root.
  final String path;
  final ChangeKind kind;

  @override
  String toString() {
    final tag = switch (kind) {
      ChangeKind.created => 'A',
      ChangeKind.modified => 'M',
      ChangeKind.deleted => 'D',
    };
    return '$tag $path';
  }
}

/// Collects file writes and deletions, then applies them all or none.
///
/// - [dryRun] only reports what would change.
/// - Before a file is changed or deleted, its old bytes are copied to
///   `<root>/.sweetmelon/backup/<timestamp>/`.
/// - If an operation fails, every operation already done is undone.
/// - With [requireCleanGit], nothing is written while `git status` reports
///   uncommitted changes. [gitStatus] returns that output, or null when git is
///   not available.
class SafeWriter {
  SafeWriter({
    this.root = '.',
    this.dryRun = false,
    this.requireCleanGit = true,
    this.gitStatus,
    Future<void> Function(File file, List<int> bytes)? writeFile,
  }) : _writeFile = writeFile ?? _defaultWrite;

  final String root;
  final bool dryRun;
  final bool requireCleanGit;
  final Future<String?> Function()? gitStatus;
  final Future<void> Function(File file, List<int> bytes) _writeFile;

  /// Path relative to [root] -> new bytes. Insertion order is kept.
  final Map<String, Uint8List> _writes = {};
  final List<String> _deletes = [];

  /// Plans a text file. The last value set for a path wins.
  void replace(String relativePath, String content) {
    replaceBytes(relativePath, Uint8List.fromList(utf8.encode(content)));
  }

  /// Plans a binary file. The last value set for a path wins.
  void replaceBytes(String relativePath, Uint8List bytes) {
    _deletes.remove(relativePath);
    _writes[relativePath] = bytes;
  }

  /// Plans the deletion of a file. Ignored when the file does not exist.
  void delete(String relativePath) {
    _writes.remove(relativePath);
    if (!_deletes.contains(relativePath)) _deletes.add(relativePath);
  }

  /// Reports the changes, and applies them unless [dryRun] is set.
  ///
  /// Throws [StateError] when git reports uncommitted changes. After a failed
  /// operation the files are restored and the original error is rethrown.
  Future<List<FileChange>> commit() async {
    final changes = <FileChange>[];
    for (final entry in _writes.entries) {
      final file = _file(entry.key);
      if (await file.exists()) {
        if (_sameBytes(await file.readAsBytes(), entry.value)) continue;
        changes.add(FileChange(entry.key, ChangeKind.modified));
      } else {
        changes.add(FileChange(entry.key, ChangeKind.created));
      }
    }
    for (final path in _deletes) {
      if (await _file(path).exists()) {
        changes.add(FileChange(path, ChangeKind.deleted));
      }
    }

    if (dryRun || changes.isEmpty) return changes;

    if (requireCleanGit && gitStatus != null) {
      final status = await gitStatus!();
      if (status != null && status.trim().isNotEmpty) {
        throw StateError(
          'The working tree has uncommitted changes. Commit or stash them, '
          'or run again with --force.',
        );
      }
    }

    final backupDir = p.join(
      root,
      '.sweetmelon',
      'backup',
      DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-'),
    );

    // path -> bytes before this run; null means the file did not exist.
    final previous = <String, Uint8List?>{};
    try {
      for (final change in changes) {
        final file = _file(change.path);
        final old =
            change.kind == ChangeKind.created ? null : await file.readAsBytes();
        if (old != null) {
          final backup = File(p.join(backupDir, change.path));
          await backup.parent.create(recursive: true);
          await backup.writeAsBytes(old);
        }
        previous[change.path] = old;

        if (change.kind == ChangeKind.deleted) {
          await file.delete();
        } else {
          await file.parent.create(recursive: true);
          await _writeFile(file, _writes[change.path]!);
        }
      }
    } catch (_) {
      await _restore(previous);
      rethrow;
    }
    return changes;
  }

  File _file(String relativePath) => File(p.join(root, relativePath));

  Future<void> _restore(Map<String, Uint8List?> previous) async {
    for (final entry in previous.entries) {
      final file = _file(entry.key);
      final old = entry.value;
      if (old == null) {
        if (await file.exists()) await file.delete();
      } else {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(old);
      }
    }
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<void> _defaultWrite(File file, List<int> bytes) async {
    await file.writeAsBytes(bytes);
  }
}

/// Returns `git status --porcelain` for the current directory, or null when
/// git is missing or the directory is not a repository.
Future<String?> gitPorcelainStatus() async {
  try {
    // Untracked files (for example pubspec.lock after `flutter pub get`) are
    // not overwritten by a write, so they do not block it.
    final result = await Process.run(
        'git', ['status', '--porcelain', '--untracked-files=no']);
    if (result.exitCode != 0) return null;
    return result.stdout.toString();
  } on ProcessException {
    return null;
  }
}
