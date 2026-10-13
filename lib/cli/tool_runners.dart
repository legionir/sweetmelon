// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'icon_generator.dart';
import 'package_rename.dart';
import 'plugin_catalog.dart';
import 'project_doctor.dart';
import 'project_settings.dart';
import 'safe_writer.dart';
import 'sync_runner.dart';
import 'version_bump.dart';

/// Files that every runner reads from the project root.
const sweetmelonYaml = 'sweetmelon.yaml';
const pubspecYaml = 'pubspec.yaml';
const gradleKts = 'android/app/build.gradle.kts';
const pluginCatalogFile = 'tool/plugin_catalog.json';

SafeWriter _writer(String root, bool apply, bool force) => SafeWriter(
      root: root,
      dryRun: !apply,
      requireCleanGit: !force,
      gitStatus: gitPorcelainStatus,
    );

/// Prints the planned changes and the next step. Returns the exit code.
Future<int> _finish(SafeWriter writer, bool apply) async {
  try {
    final changes = await writer.commit();
    if (changes.isEmpty) {
      print('Nothing to change.');
      return 0;
    }
    for (final change in changes) {
      print('  $change');
    }
    print('');
    print(apply ? 'Written.' : 'Dry run. Run again with --apply to write.');
    return 0;
  } on StateError catch (e) {
    print('Not written: ${e.message}');
    return 1;
  }
}

/// `sweetmelon bump <build|patch|minor|major>`.
///
/// The version name lives in `project.version` (sweetmelon.yaml). The build
/// number lives in the `+n` part of the pubspec version. Both are written
/// together.
class BumpRunner {
  BumpRunner({this.root = '.'});

  final String root;

  Future<int> run(
    BumpKind kind, {
    bool apply = false,
    bool force = false,
  }) async {
    final yamlFile = File(p.join(root, sweetmelonYaml));
    final pubspecFile = File(p.join(root, pubspecYaml));
    if (!await yamlFile.exists() || !await pubspecFile.exists()) {
      print('sweetmelon.yaml and pubspec.yaml are required');
      return 1;
    }
    final yamlText = await yamlFile.readAsString();
    final pubspecText = await pubspecFile.readAsString();

    final settings = ProjectSettings.fromYaml(yamlText);
    final pubspec = readPubspecVersion(pubspecText);
    if (pubspec == null) {
      print('pubspec.yaml has no "version:" line');
      return 1;
    }
    final next = bumpVersion(
      name: settings.version,
      build: pubspec.build,
      kind: kind,
    );

    print('Version: ${settings.version}+${pubspec.build} -> ${next.full}');
    final writer = _writer(root, apply, force)
      ..replace(sweetmelonYaml, setProjectVersion(yamlText, next.name))
      ..replace(pubspecYaml, setPubspecVersion(pubspecText, next));
    return _finish(writer, apply);
  }
}

/// `sweetmelon icon <square png, at least 1024 px>`.
///
/// Writes the Android launcher icons, the iOS AppIcon set and the web icons.
/// Obsolete AppIcon PNGs that the old Contents.json listed are deleted.
class IconRunner {
  IconRunner({this.root = '.'});

  final String root;

  Future<int> run(
    String sourcePath, {
    bool apply = false,
    bool force = false,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      print('Icon source not found: $sourcePath');
      return 1;
    }
    final bytes = Uint8List.fromList(await source.readAsBytes());
    final problem = iconSourceProblem(bytes);
    if (problem != null) {
      print('Icon source rejected: $problem');
      return 1;
    }

    final targets = iconTargets();
    final rendered = renderIcons(bytes, targets);

    final writer = _writer(root, apply, force);
    rendered.forEach(writer.replaceBytes);

    final contentsPath = p.join(iosAppIconDir, 'Contents.json');
    final newContents = iosContentsJson();
    final contents = File(p.join(root, contentsPath));
    final keep = {for (final spec in iosIconSpecs) spec.fileName};
    if (await contents.exists()) {
      for (final name in iosFileNamesIn(await contents.readAsString())) {
        if (!keep.contains(name)) {
          writer.delete(p.join(iosAppIconDir, name));
        }
      }
    }
    writer.replace(contentsPath, newContents);

    print('Icon: ${targets.length} files from $sourcePath');
    return _finish(writer, apply);
  }
}

/// `sweetmelon rename [--id com.acme.app]`.
///
/// Changes the Android applicationId and the iOS bundle id in native files.
/// The target is `project.application_id`, unless [newId] is given. A given
/// [newId] is also written to sweetmelon.yaml.
class RenameRunner {
  RenameRunner({this.root = '.'});

  final String root;

  Future<int> run({
    String? newId,
    bool apply = false,
    bool force = false,
  }) async {
    final gradle = File(p.join(root, gradleKts));
    if (!await gradle.exists()) {
      print('$gradleKts not found');
      return 1;
    }
    final oldId = readGradleApplicationId(await gradle.readAsString());
    if (oldId == null) {
      print('applicationId not found in $gradleKts');
      return 1;
    }

    final yamlFile = File(p.join(root, sweetmelonYaml));
    final yamlText =
        await yamlFile.exists() ? await yamlFile.readAsString() : '';
    final target = newId ?? ProjectSettings.fromYaml(yamlText).applicationId;
    if (target == null) {
      print('No target id: set project.application_id in sweetmelon.yaml '
          'or pass --id');
      return 1;
    }

    final idProblem = validateApplicationId(target);
    if (idProblem != null) {
      print(idProblem);
      return 1;
    }
    if (target == oldId) {
      print('Already $oldId: nothing to rename');
      return 0;
    }

    final texts = await _readTexts(['android', 'ios']);
    final RenamePlan plan;
    try {
      plan = planPackageRename(oldId: oldId, newId: target, texts: texts);
    } on FormatException catch (e) {
      print(e.message);
      return 1;
    }

    print('Rename $oldId -> $target');
    for (final warning in plan.warnings) {
      print('  ⚠️  $warning');
    }

    final writer = _writer(root, apply, force);
    for (final file in plan.files) {
      writer.replace(file.newPath, file.content);
      if (file.isMove) writer.delete(file.oldPath);
    }
    if (newId != null && yamlText.isNotEmpty) {
      writer.replace(sweetmelonYaml, setProjectApplicationId(yamlText, target));
    }

    final code = await _finish(writer, apply);
    if (code == 0 && apply) {
      await _removeEmptyDirs(oldId.replaceAll('.', '/'));
    }
    return code;
  }

  Future<Map<String, String>> _readTexts(List<String> tops) async {
    final texts = <String, String>{};
    for (final top in tops) {
      final dir = Directory(p.join(root, top));
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is! File) continue;
        final relative =
            p.relative(entity.path, from: root).replaceAll('\\', '/');
        try {
          texts[relative] = await entity.readAsString();
        } on Exception {
          // Binary file (not valid UTF-8): not a candidate for renaming.
        }
      }
    }
    return texts;
  }

  /// Deletes empty folders left behind under the old Kotlin package path.
  Future<void> _removeEmptyDirs(String oldDir) async {
    final base = Directory(p.join(root, androidKotlinRoot, oldDir));
    var dir = base;
    final stop = p.join(root, androidKotlinRoot);
    while (p.isWithin(stop, dir.path) && await dir.exists()) {
      if (await dir.list().isEmpty) {
        await dir.delete();
        dir = dir.parent;
      } else {
        break;
      }
    }
  }
}

/// `sweetmelon rename --dart-package my_app`.
///
/// Changes the Dart package name: `name:` in pubspec.yaml, the dependency key
/// in plugin pubspecs and every `package:<old>/` import (see
/// [planDartPackageRename]). Run `flutter pub get` afterwards, which rewrites
/// pubspec.lock and .dart_tool.
class DartPackageRenameRunner {
  DartPackageRenameRunner({this.root = '.'});

  final String root;

  Future<int> run(
    String newName, {
    bool apply = false,
    bool force = false,
  }) async {
    final pubspec = File(p.join(root, pubspecYaml));
    if (!await pubspec.exists()) {
      print('$pubspecYaml not found');
      return 1;
    }
    final oldName = readPubspecName(await pubspec.readAsString());
    if (oldName == null) {
      print('name not found in $pubspecYaml');
      return 1;
    }
    if (oldName == newName) {
      print('Already $oldName: nothing to rename');
      return 0;
    }

    final texts = await _readTexts();
    final DartRenamePlan plan;
    try {
      plan = planDartPackageRename(
          oldName: oldName, newName: newName, texts: texts);
    } on FormatException catch (e) {
      print(e.message);
      return 1;
    }

    print('Rename Dart package $oldName -> $newName '
        '(${plan.files.length} files)');
    final writer = _writer(root, apply, force);
    for (final entry in plan.files.entries) {
      writer.replace(entry.key, entry.value);
    }
    final code = await _finish(writer, apply);
    if (code == 0 && apply && !plan.isEmpty) {
      print('Next: flutter pub get');
    }
    return code;
  }

  Future<Map<String, String>> _readTexts() async {
    final texts = <String, String>{};
    Future<void> read(File file) async {
      final relative = p.relative(file.path, from: root).replaceAll('\\', '/');
      try {
        texts[relative] = await file.readAsString();
      } on Exception {
        // Not valid UTF-8: not a candidate.
      }
    }

    final rootPubspec = File(p.join(root, pubspecYaml));
    if (await rootPubspec.exists()) await read(rootPubspec);
    for (final top in dartRenameRoots) {
      final dir = Directory(p.join(root, top));
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        final isNestedPubspec = top == 'lib' && name == pubspecYaml;
        if (isNestedPubspec ||
            entity.path.endsWith('.dart') ||
            entity.path.endsWith('.json')) {
          await read(entity);
        }
      }
    }
    return texts;
  }
}

/// `sweetmelon doctor` project checks (see project_doctor.dart).
class DoctorRunner {
  DoctorRunner({this.root = '.'});

  final String root;

  /// Prints every finding. Returns 1 when any check failed.
  Future<int> run() async {
    final snapshot = await _snapshot();
    final findings = checkProject(snapshot);
    for (final finding in findings) {
      print('  $finding');
    }
    final failed = findings.where((f) => f.level == DoctorLevel.fail).length;
    final warned = findings.where((f) => f.level == DoctorLevel.warn).length;
    print('');
    print('Project checks: $failed failed, $warned warnings');
    return failed == 0 ? 0 : 1;
  }

  Future<ProjectSnapshot> _snapshot() async {
    // Only the paths the checks look at, so build folders are not scanned.
    final candidates = <String>{
      for (final target in iconTargets()) target.path,
      '$iosAppIconDir/Contents.json',
      'android/key.properties',
    };
    final paths = <String>{
      for (final path in candidates)
        if (await File(p.join(root, path)).exists()) path,
    };

    Future<String?> read(String relative) async {
      final file = File(p.join(root, relative));
      return await file.exists() ? file.readAsString() : null;
    }

    final pluginDirs = <String>{};
    final pluginsRoot = Directory(p.join(root, 'lib', 'plugins'));
    if (await pluginsRoot.exists()) {
      await for (final entity in pluginsRoot.list()) {
        if (entity is Directory) pluginDirs.add(p.basename(entity.path));
      }
    }

    final catalog = await PluginCatalog.load(
      p.join(root, pluginCatalogFile),
    );
    final locator = await read('lib/di/service_locator.dart');
    final registeredPluginKeys = catalog == null || locator == null
        ? null
        : {
            for (final entry in catalog.entries)
              if (locator
                  .contains("import 'package:sweetmelon/${entry.importPath}';"))
                entry.yamlKey,
          };
    SyncPlan? plan;
    try {
      plan = await SyncRunner(root: root).plan();
    } on StateError {
      plan = null; // sweetmelon.yaml is missing: reported by the yaml check.
    }

    return ProjectSnapshot(
      paths: paths,
      yaml: await read(sweetmelonYaml),
      pubspec: await read(pubspecYaml),
      gradle: await read(gradleKts),
      googleServices: await read('android/app/google-services.json'),
      catalogKeys: catalog?.yamlKeys,
      registeredPluginKeys: registeredPluginKeys,
      pluginDirs: pluginDirs,
      syncWarnings: plan?.warnings ?? const [],
      pendingSync: [
        for (final path in plan?.changes.keys ?? const <String>[])
          '$path is out of date',
      ],
    );
  }
}
