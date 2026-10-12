/// Planner for renaming the Android applicationId and the iOS bundle id.
///
/// Only native files change: the Dart package name (`sweetmelon`) and every
/// Dart import stay as they are.
///
/// Rules:
/// - In every text file, the old id is replaced as a whole identifier. It
///   must not be preceded by `[A-Za-z0-9_.]` and not followed by
///   `[A-Za-z0-9_]`, so `com.core.sweetmelonX` and `x.com.core.sweetmelon` are
///   left alone, while `com.core.sweetmelon.MainActivity` is renamed.
/// - A Kotlin file under `<kotlinRoot>/<old path>/` whose `package` line is
///   the old id is moved to `<kotlinRoot>/<new path>/`. Other files in that
///   folder are left in place and reported as warnings.
library;

const androidKotlinRoot = 'android/app/src/main/kotlin';

/// Extensions of files that may contain the application id.
const renameTextExtensions = <String>{
  '.kts',
  '.gradle',
  '.kt',
  '.java',
  '.xml',
  '.plist',
  '.pbxproj',
  '.pro',
  '.properties',
  '.swift',
  '.m',
  '.h',
  '.xcconfig',
  '.xcscheme',
  '.entitlements',
  '.json',
  '.md',
};

final _idPattern = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');

/// Words that cannot be a package segment in Java or Kotlin.
const _reservedSegments = <String>{
  'abstract',
  'assert',
  'boolean',
  'break',
  'byte',
  'case',
  'catch',
  'char',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'double',
  'else',
  'enum',
  'extends',
  'final',
  'finally',
  'float',
  'for',
  'goto',
  'if',
  'implements',
  'import',
  'instanceof',
  'int',
  'interface',
  'long',
  'native',
  'new',
  'package',
  'private',
  'protected',
  'public',
  'return',
  'short',
  'static',
  'strictfp',
  'super',
  'switch',
  'synchronized',
  'this',
  'throw',
  'throws',
  'transient',
  'try',
  'void',
  'volatile',
  'while',
  'true',
  'false',
  'null',
  'val',
  'var',
  'fun',
  'when',
  'object',
  'typealias',
  'is',
  'in',
  'as',
};

/// Returns a problem description, or null when [id] can be used as an
/// application id.
String? validateApplicationId(String id) {
  if (!_idPattern.hasMatch(id)) {
    return 'application id "$id" must look like com.acme.app (lowercase '
        'letters, digits and underscores, at least two segments, each starting '
        'with a letter)';
  }
  for (final segment in id.split('.')) {
    if (_reservedSegments.contains(segment)) {
      return 'application id segment "$segment" is a reserved word';
    }
  }
  return null;
}

/// Reads `applicationId = "..."` from android/app/build.gradle.kts text.
String? readGradleApplicationId(String gradle) {
  final match = RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle);
  return match?.group(1);
}

/// One file to write. When [oldPath] differs from [newPath], the old file is
/// deleted after the new one is written.
class RenameFile {
  const RenameFile({
    required this.oldPath,
    required this.newPath,
    required this.content,
  });

  final String oldPath;
  final String newPath;
  final String content;

  bool get isMove => oldPath != newPath;
}

class RenamePlan {
  const RenamePlan({
    required this.oldId,
    required this.newId,
    required this.files,
    required this.warnings,
  });

  final String oldId;
  final String newId;

  /// Only files that change: edited in place or moved.
  final List<RenameFile> files;
  final List<String> warnings;

  bool get isEmpty => files.isEmpty;
}

/// Plans the rename.
///
/// [texts] maps project-relative paths (with '/') to file content. It should
/// hold the android/ and ios/ text files. Other paths are ignored.
RenamePlan planPackageRename({
  required String oldId,
  required String newId,
  required Map<String, String> texts,
  String kotlinRoot = androidKotlinRoot,
}) {
  final problem = validateApplicationId(newId);
  if (problem != null) throw FormatException(problem);
  if (oldId == newId) {
    throw const FormatException(
        'the new application id is the same as the old');
  }

  final oldRe = _wholeIdentifier(oldId);
  final oldDir = oldId.replaceAll('.', '/');
  final newDir = newId.replaceAll('.', '/');
  final kotlinPrefix = '$kotlinRoot/$oldDir/';
  final packageLine = RegExp(
    r'^\s*package\s+' + RegExp.escape(oldId) + r'\s*$',
    multiLine: true,
  );

  final files = <RenameFile>[];
  final warnings = <String>[];

  final paths = texts.keys.where(_isRenameable).toList()..sort();
  for (final path in paths) {
    final original = texts[path]!;
    final edited = original.replaceAll(oldRe, newId);

    final isKotlinInOldDir = path.startsWith(kotlinPrefix);
    if (isKotlinInOldDir && path.endsWith('.kt')) {
      if (packageLine.hasMatch(original)) {
        final rest = path.substring(kotlinPrefix.length);
        final target = '$kotlinRoot/$newDir/$rest';
        files.add(RenameFile(oldPath: path, newPath: target, content: edited));
        continue;
      }
      warnings.add('$path stays in $oldDir: its package is not $oldId');
    }

    if (edited != original) {
      files.add(RenameFile(oldPath: path, newPath: path, content: edited));
    }
  }

  return RenamePlan(
      oldId: oldId, newId: newId, files: files, warnings: warnings);
}

bool _isRenameable(String path) {
  if (!path.startsWith('android/') && !path.startsWith('ios/')) return false;
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  return renameTextExtensions.contains(path.substring(dot).toLowerCase());
}

RegExp _wholeIdentifier(String id) {
  return RegExp(
    '(?<![A-Za-z0-9_.])${RegExp.escape(id)}(?![A-Za-z0-9_])',
  );
}

/// Exposed for tests.
String renameIdentifierInText(String text, String oldId, String newId) =>
    text.replaceAll(_wholeIdentifier(oldId), newId);
