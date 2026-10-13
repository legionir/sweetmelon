// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'core_compat.dart';
import 'icon_generator.dart';
import 'package_rename.dart';
import 'plugin_catalog.dart';
import 'plugin_detect.dart';
import 'plugin_selection.dart';
import 'project_settings.dart';
import 'sync_runner.dart';
import 'tool_runners.dart';

/// Files of the JS bridge that always come from the core, never from the app.
const sdkFiles = [
  'js/native-sdk.js',
  'js/native-sdk.d.ts',
  'js/native-resilience.js',
];

/// Values that win over sweetmelon.yaml (workflow inputs, CLI options).
class PrepareOverrides {
  const PrepareOverrides({
    this.www,
    this.applicationId,
    this.dartPackage,
    this.appName,
    this.icon,
  });

  final String? www;
  final String? applicationId;
  final String? dartPackage;
  final String? appName;
  final String? icon;
}

/// `sweetmelon prepare`: everything between a fresh core checkout and
/// `flutter build`.
///
/// Order: validate -> core compatibility -> inject `www` -> plugin selection ->
/// write overrides into sweetmelon.yaml -> rename application id -> rename Dart
/// package -> icon -> sync. Every step can be repeated, so running `prepare`
/// twice with the same input changes nothing the second time.
///
/// Without [apply] nothing is written; the plan is printed.
class PrepareRunner {
  PrepareRunner({this.root = '.'});

  final String root;

  Future<int> run(PrepareOverrides overrides,
      {bool apply = false, bool strict = false}) async {
    final yamlFile = File(p.join(root, sweetmelonYaml));
    if (!await yamlFile.exists()) {
      print('$sweetmelonYaml not found in $root');
      return 1;
    }
    var yaml = await yamlFile.readAsString();

    // 1. Core compatibility.
    final core = ProjectSettings.readCore(yaml);
    if (core == null) {
      print(
          '⚠️  no "core:" in $sweetmelonYaml; the core version is not checked');
    } else {
      final problem = checkCoreCompatibility(core);
      if (problem != null) {
        print(problem);
        return 1;
      }
    }

    // 2. Inputs and their precedence: override > yaml.
    final settings = ProjectSettings.fromYaml(yaml);
    final applicationId = overrides.applicationId ?? settings.applicationId;
    final dartPackage = overrides.dartPackage ?? settings.dartPackage;
    final appName = overrides.appName ??
        (settings.displayName.isEmpty ? null : settings.displayName);
    final icon = overrides.icon ?? settings.icon;

    final idProblem =
        applicationId == null ? null : validateApplicationId(applicationId);
    if (idProblem != null) {
      print(idProblem);
      return 1;
    }
    final nameProblem =
        dartPackage == null ? null : validateDartPackageName(dartPackage);
    if (nameProblem != null) {
      print(nameProblem);
      return 1;
    }
    final wwwDir = overrides.www;
    if (wwwDir != null && !File(p.join(wwwDir, 'index.html')).existsSync()) {
      print('www folder $wwwDir has no index.html');
      return 1;
    }
    if (icon != null && !File(p.join(root, icon)).existsSync()) {
      print('Icon file not found: $icon');
      return 1;
    }
    if (icon != null) {
      final iconProblem = iconSourceProblem(
          Uint8List.fromList(await File(p.join(root, icon)).readAsBytes()));
      if (iconProblem != null) {
        print('Icon rejected: $iconProblem');
        return 1;
      }
    }

    final selection = PluginSelection.fromYaml(yaml);
    DetectResult? detected;
    if (selection.mode == SelectionMode.auto) {
      final scanDir = wwwDir ?? p.join(root, 'assets', 'www');
      detected = await detectInProject(root, scanDir);
      if (detected == null) {
        print('plugin_selection.mode auto needs tool/plugin_catalog.json and '
            'assets/www/js/native-sdk.js');
        return 1;
      }
      DetectRunner.printReport(detected, scanDir, strict: strict);
      if (strict && detected.dynamicUses.isNotEmpty) return 1;
      print('');
    }
    final catalog =
        await PluginCatalog.load(p.join(root, 'tool', 'plugin_catalog.json'));
    final plugins =
        _selectedPlugins(yaml, selection, detected, catalog?.yamlKeys ?? {});
    if (plugins == null) return 1;

    print('Prepare');
    print('  application id : ${applicationId ?? '(unchanged)'}');
    print('  dart package   : ${dartPackage ?? '(unchanged)'}');
    print('  app name       : ${appName ?? '(unchanged)'}');
    print('  icon           : ${icon ?? '(unchanged)'}');
    print('  www            : ${wwwDir ?? '(unchanged)'}');
    print(
        '  plugins on     : ${(plugins.entries.where((e) => e.value).map((e) => e.key).toList()..sort()).join(', ')}');
    if (!apply) {
      print('');
      print('Dry run. Run again with --apply to write.');
      return 0;
    }

    // 3. Inject www.
    if (wwwDir != null) await _injectWww(wwwDir);

    // 4. Write the effective values back to sweetmelon.yaml.
    if (applicationId != null) {
      yaml = setProjectKey(yaml, 'application_id', applicationId);
    }
    if (dartPackage != null) {
      yaml = setProjectKey(yaml, 'dart_package', dartPackage);
    }
    if (appName != null) {
      yaml = setProjectKey(yaml, 'display_name', _yamlString(appName));
    }
    if (icon != null) yaml = setProjectKey(yaml, 'icon', icon);
    plugins.forEach((key, on) =>
        yaml = setPluginEnabled(yaml, key, on, addIfMissing: true));
    await yamlFile.writeAsString(yaml);

    // 5. Native and Dart renames, icon, sync.
    var code = 0;
    if (applicationId != null) {
      code = await RenameRunner(root: root).run(apply: true, force: true);
      if (code != 0) return code;
    }
    if (dartPackage != null) {
      code = await DartPackageRenameRunner(root: root)
          .run(dartPackage, apply: true, force: true);
      if (code != 0) return code;
    }
    if (icon != null) {
      code = await IconRunner(root: root)
          .run(p.join(root, icon), apply: true, force: true);
      if (code != 0) return code;
    }
    return SyncRunner(root: root)
        .run(const SyncOptions(apply: true, force: true), check: false);
  }

  /// `plugins:` flags after include/exclude. Null when a name is unknown.
  ///
  /// In auto mode every plugin starts off and only the [detected] ones (plus
  /// include) are on.
  Map<String, bool>? _selectedPlugins(String yaml, PluginSelection selection,
      DetectResult? detected, Set<String> catalogKeys) {
    final doc = loadYaml(yaml);
    final section = doc is YamlMap ? doc['plugins'] : null;
    // A plugin missing from the file counts as enabled, so the full catalog
    // is listed: every plugin gets an explicit flag.
    final result = <String, bool>{for (final key in catalogKeys) key: true};
    if (section is YamlMap) {
      for (final entry in section.entries) {
        final settings = entry.value;
        final flag = settings is YamlMap ? settings['enabled'] : null;
        result[entry.key.toString()] = flag is bool ? flag : true;
      }
    }
    if (detected != null) {
      for (final key in result.keys.toList()) {
        result[key] = detected.plugins.contains(key);
      }
      for (final key in detected.plugins) {
        if (!result.containsKey(key)) {
          print('⚠️  $key is used but is not a known plugin');
        }
      }
    }
    for (final name in [...selection.include, ...selection.exclude]) {
      if (!result.containsKey(name)) {
        print('plugin_selection names "$name", which is not a known plugin');
        return null;
      }
    }
    for (final name in selection.include) {
      result[name] = true;
    }
    for (final name in selection.exclude) {
      result[name] = false;
    }
    return result;
  }

  /// Replaces assets/www with [source]; the bridge files come from the core.
  Future<void> _injectWww(String source) async {
    final target = Directory(p.join(root, 'assets', 'www'));
    final kept = <String, List<int>>{};
    for (final name in sdkFiles) {
      final file = File(p.join(target.path, name));
      if (await file.exists()) kept[name] = await file.readAsBytes();
    }
    if (await target.exists()) await target.delete(recursive: true);
    await target.create(recursive: true);
    final src = Directory(source);
    await for (final entity in src.list(recursive: true)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: src.path);
      final out = File(p.join(target.path, relative));
      await out.parent.create(recursive: true);
      await entity.copy(out.path);
    }
    for (final entry in kept.entries) {
      final out = File(p.join(target.path, entry.key));
      await out.parent.create(recursive: true);
      await out.writeAsBytes(entry.value);
    }
    print('www: copied $source -> assets/www');
  }

  String _yamlString(String value) =>
      '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}
