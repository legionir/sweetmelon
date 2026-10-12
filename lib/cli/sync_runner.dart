// ignore_for_file: avoid_print
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'analysis_excludes.dart';
import 'native_sync.dart';
import 'plugin_catalog.dart';
import 'plugin_closure.dart';
import 'plugin_registry_data.dart';
import 'project_settings.dart';
import 'pubspec_sync.dart';
import 'safe_writer.dart';
import 'service_locator_gen.dart';
import 'version_bump.dart';
import 'web_sync.dart';

class SyncOptions {
  const SyncOptions({this.apply = false, this.force = false});

  /// Write the changes. Without it, only the report is printed.
  final bool apply;

  /// Write even when git reports uncommitted changes.
  final bool force;
}

/// The result of [SyncRunner.plan]: what would change, and why.
class SyncPlan {
  const SyncPlan({
    required this.report,
    required this.changes,
    required this.warnings,
  });

  /// Human-readable lines, one per synced area.
  final List<String> report;

  /// Project-relative path -> new content. Only files whose content changes.
  final Map<String, String> changes;

  /// Problems that the sync cannot fix by itself, e.g. a plugin that is off in
  /// sweetmelon.yaml but still imported by application code.
  final List<String> warnings;

  bool get hasChanges => changes.isNotEmpty;
}

/// Brings every generated project file in line with sweetmelon.yaml:
/// - service_locator.dart: only enabled catalog plugins are registered;
/// - pubspec.yaml: unused dependencies of disabled plugins are removed, and
///   the version name comes from `project.version`;
/// - analysis_options.yaml and tool/sweetmelon_test_targets.txt: disabled
///   plugin sources and their tests stay out of analyze/test while their source
///   remains in the repository;
/// - AndroidManifest.xml and ios/Runner/Info.plist: registry-managed
///   permissions are added or removed;
/// - web/index.html, assets/www/index.html and web/manifest.json: title and
///   app name come from `project.display_name`.
class SyncRunner {
  SyncRunner({this.root = '.'});

  final String root;

  static const _pubspec = 'pubspec.yaml';
  static const _serviceLocator = 'lib/di/service_locator.dart';
  static const _catalog = 'tool/plugin_catalog.json';
  static const _manifest = 'android/app/src/main/AndroidManifest.xml';
  static const _infoPlist = 'ios/Runner/Info.plist';
  static const _webIndexes = ['web/index.html', 'assets/www/index.html'];
  static const _webManifest = 'web/manifest.json';

  /// Computes the changes without writing anything.
  Future<SyncPlan> plan() async {
    final project = await _readProject();
    final enabled = await _readEnabled();
    final pluginDeps = await _pluginDeps();
    final files = await _appCodeFiles();
    final report = <String>[];
    final warnings = <String>[];
    final changes = <String, String>{};

    // Render service_locator before calculating the dependency closure. The
    // committed locator can still contain stale imports from an earlier yaml;
    // letting those imports influence the calculation would retain disabled
    // plugins and all of their external packages forever.
    final catalog = await PluginCatalog.load(p.join(root, _catalog));
    if (catalog == null) {
      warnings.add('$_catalog not found: service_locator.dart was not synced');
    } else {
      final locatorFile = File(p.join(root, _serviceLocator));
      if (await locatorFile.exists()) {
        final before = await locatorFile.readAsString();
        final locatorEnabled = <String>{
          for (final key in catalog.yamlKeys)
            if (enabled[key] ?? true) key,
        };
        final after = renderServiceLocator(
          before,
          catalog.entries,
          enabledKeys: locatorEnabled,
        );
        files[_serviceLocator] = after;
        _record(changes, _serviceLocator, after, before);
        report.add('service locator: ${locatorEnabled.length} of '
            '${catalog.yamlKeys.length} catalog plugins enabled');
      } else {
        warnings.add(
            '$_serviceLocator not found: plugin registrations were not synced');
      }
    }

    final closure = PluginClosure.compute(
      files: files,
      pluginDeps: pluginDeps,
      enabled: enabled,
    );

    bool isActive(String id) => pluginDeps.containsKey(id)
        ? closure.activeDirs.contains(id)
        : (enabled[id] ?? true);

    final disabledDirs = pluginDeps.keys
        .where((dir) => !closure.activeDirs.contains(dir))
        .toList()
      ..sort();
    report.add(
        'plugins off: ${disabledDirs.isEmpty ? '-' : disabledDirs.join(', ')}');
    for (final entry in closure.importedBy.entries) {
      if (enabled[entry.key] == false) {
        warnings.add('"${entry.key}" is off in sweetmelon.yaml but '
            '${entry.value} still imports or depends on it, so it stays in the build.');
      }
    }

    // Keep only tests that do not directly import a disabled plugin. Source
    // tests are preserved so toggling the yaml flag and syncing restores them.
    final allTestFiles = await _testFiles();
    final disabledTests = <String>[];
    final activeTests = <String>[];
    for (final entry in allTestFiles.entries) {
      final imports = importedPluginDirectories(entry.value);
      if (imports.any((dir) => !closure.activeDirs.contains(dir))) {
        disabledTests.add(entry.key);
      } else {
        activeTests.add(entry.key);
      }
    }

    final analysisOptions = File(p.join(root, analysisExcludesPath));
    if (await analysisOptions.exists()) {
      final before = await analysisOptions.readAsString();
      final after = syncAnalysisExcludes(
        before,
        disabledPluginDirs: disabledDirs,
        disabledTestPaths: disabledTests,
      );
      _record(changes, analysisExcludesPath, after, before);
      report.add(
          'analyzer exclusions: ${disabledDirs.length} plugin directories, '
          '${disabledTests.length} test files');
    } else {
      warnings.add(
          '$analysisExcludesPath not found: disabled plugin sources are analyzed');
    }

    final testTargets = File(p.join(root, activeTestTargetsPath));
    final beforeTargets =
        await testTargets.exists() ? await testTargets.readAsString() : '';
    final afterTargets = renderActiveTestTargets(activeTests);
    _record(changes, activeTestTargetsPath, afterTargets, beforeTargets);
    report.add('test targets: ${activeTests.length} active, '
        '${disabledTests.length} skipped for disabled plugins');

    // pubspec.yaml: version name and dependencies
    final pubspecFile = File(p.join(root, _pubspec));
    if (await pubspecFile.exists()) {
      final original = await pubspecFile.readAsString();
      var text = original;
      final disabledDeps = <String>{
        for (final dir in disabledDirs) ...?pluginDeps[dir],
      };
      final result = removeUnusedDependencies(
        text,
        disabledPluginDeps: disabledDeps,
        neededPackages: closure.neededPackages,
      );
      text = result.text;
      report.add('dependencies: '
          '${result.removed.isEmpty ? 'no change' : '-${result.removed.join(', ')}'}');

      final current = readPubspecVersion(text);
      if (project.version.isNotEmpty && current != null) {
        final wanted = BuildVersion(project.version, current.build);
        if (wanted.name != current.name) {
          text = setPubspecVersion(text, wanted);
          report.add('version: ${current.name} -> ${wanted.name}');
        } else {
          report.add('version: no change (${current.name})');
        }
      }
      _record(changes, _pubspec, text, original);
    }

    const registry = PluginRegistryData.allPlugins;

    // Android permissions
    final androidManaged = <String>{
      for (final plugin in registry) ...plugin.androidPermissions,
    };
    // The WebView-hosted application itself needs Internet access even when
    // the optional http_native bridge plugin is disabled.
    final androidDesired = <String>['android.permission.INTERNET'];
    final androidFeaturesManaged = <String>{
      for (final plugin in registry) ...plugin.androidFeatures,
    };
    final androidFeaturesDesired = <String>[];
    for (final plugin in registry) {
      if (!isActive(plugin.id)) continue;
      for (final permission in plugin.androidPermissions) {
        if (!androidDesired.contains(permission)) {
          androidDesired.add(permission);
        }
      }
      for (final feature in plugin.androidFeatures) {
        if (!androidFeaturesDesired.contains(feature)) {
          androidFeaturesDesired.add(feature);
        }
      }
    }

    final manifestFile = File(p.join(root, _manifest));
    if (await manifestFile.exists()) {
      final before = await manifestFile.readAsString();
      final permissionsSynced = syncAndroidPermissions(
        before,
        managed: androidManaged,
        desired: androidDesired,
      );
      final featuresSynced = syncAndroidFeatures(
        permissionsSynced,
        managed: androidFeaturesManaged,
        desired: androidFeaturesDesired,
      );
      final after = _setAndroidLabel(featuresSynced, project.displayName);
      _record(changes, _manifest, after, before);
      report.add('Android permissions: '
          '${_diff(androidPermissionNames(before), androidPermissionNames(after))}');
      report.add('Android features: '
          '${_diff(androidFeatureNames(before), androidFeatureNames(after))}');
    }

    // iOS usage descriptions
    final iosManaged = <String>{
      for (final plugin in registry) ...plugin.iosPermissions.keys,
    };
    final iosDesired = <String, String>{};
    for (final plugin in registry) {
      if (!isActive(plugin.id)) continue;
      plugin.iosPermissions.forEach((key, text) {
        iosDesired.putIfAbsent(key, () => text);
      });
    }

    final plistFile = File(p.join(root, _infoPlist));
    if (await plistFile.exists()) {
      final before = await plistFile.readAsString();
      final synced = syncIosUsageDescriptions(
        before,
        managedKeys: iosManaged,
        desired: iosDesired,
      );
      final after = _setPlistDisplayName(synced, project.displayName);
      _record(changes, _infoPlist, after, before);
      report.add('iOS usage keys: '
          '${_diff(_plistKeys(before), _plistKeys(after))}');
    }

    // Web: titles and manifest name
    final title = project.displayName;
    if (title.isNotEmpty) {
      for (final path in _webIndexes) {
        final file = File(p.join(root, path));
        if (!await file.exists()) continue;
        final before = await file.readAsString();
        _record(changes, path, syncHtmlTitle(before, title), before);
      }
      final manifest = File(p.join(root, _webManifest));
      if (await manifest.exists()) {
        final before = await manifest.readAsString();
        _record(changes, _webManifest, syncWebManifest(before, name: title),
            before);
      }
      report.add('web title and app name: $title');
    } else {
      warnings.add('project.display_name is empty: web titles were not synced');
    }

    return SyncPlan(report: report, changes: changes, warnings: warnings);
  }

  /// Runs the sync. Returns the process exit code:
  /// - 0: nothing to change, or the changes were written (with `apply`).
  /// - 1: changes are pending and `check` is set, or the write was refused.
  Future<int> run(SyncOptions options, {bool check = false}) async {
    final plan = await this.plan();

    print('Sync plan');
    if (plan.hasChanges) {
      print('  pending files: ${plan.changes.keys.join(', ')}');
      for (final entry in plan.changes.entries) {
        final current = File(p.join(root, entry.key));
        final before =
            await current.exists() ? await current.readAsString() : '';
        print('  ${entry.key}: ${_firstDifference(before, entry.value)}');
      }
    }
    for (final line in plan.report) {
      print('  $line');
    }
    for (final warning in plan.warnings) {
      print('  ⚠️  $warning');
    }
    print('');

    if (!plan.hasChanges) {
      print('Nothing to change.');
      return 0;
    }

    final writer = SafeWriter(
      root: root,
      dryRun: !options.apply,
      requireCleanGit: !options.force,
      gitStatus: gitPorcelainStatus,
    );
    plan.changes.forEach(writer.replace);

    try {
      final planned = await writer.commit();
      for (final change in planned) {
        print('  $change');
      }
      print('');
      if (check) {
        print(
            'Out of date: run "sweetmelon sync --apply" and commit the result.');
        return 1;
      }
      if (options.apply) {
        print('Written. Run "flutter pub get" before building.');
      } else {
        print('Dry run. Run again with --apply to write these files.');
      }
      return 0;
    } on StateError catch (e) {
      print('Not written: ${e.message}');
      return 1;
    }
  }

  void _record(
    Map<String, String> changes,
    String path,
    String after,
    String before,
  ) {
    if (after == before) return;
    changes[path] = after;
  }

  /// Sets the launcher label (android:label on <application>).
  String _setAndroidLabel(String manifest, String label) {
    if (label.isEmpty) return manifest;
    return manifest.replaceFirstMapped(
      RegExp(r'(<application\b[\s\S]*?android:label=")[^"]*(")'),
      (m) => '${m[1]!}${_xmlEscape(label)}${m[2]!}',
    );
  }

  /// Sets CFBundleDisplayName in Info.plist.
  String _setPlistDisplayName(String plist, String label) {
    if (label.isEmpty) return plist;
    return plist.replaceFirstMapped(
      RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)'),
      (m) => '${m[1]!}${_xmlEscape(label)}${m[2]!}',
    );
  }

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  Future<ProjectSettings> _readProject() async {
    final file = File(p.join(root, 'sweetmelon.yaml'));
    if (!await file.exists()) {
      throw StateError('sweetmelon.yaml not found in $root');
    }
    return ProjectSettings.fromYaml(await file.readAsString());
  }

  Future<Map<String, bool>> _readEnabled() async {
    final file = File(p.join(root, 'sweetmelon.yaml'));
    final yaml = loadYaml(await file.readAsString());
    final plugins = yaml is YamlMap ? yaml['plugins'] : null;
    final result = <String, bool>{};
    if (plugins is YamlMap) {
      for (final entry in plugins.entries) {
        final settings = entry.value;
        final flag = settings is YamlMap ? settings['enabled'] : null;
        result[entry.key.toString()] = flag is bool ? flag : true;
      }
    }
    return result;
  }

  /// Plugin directory name -> packages from its pubspec.yaml.
  Future<Map<String, Set<String>>> _pluginDeps() async {
    final result = <String, Set<String>>{};
    final dir = Directory(p.join(root, 'lib', 'plugins'));
    if (!await dir.exists()) return result;
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final pubspec = File(p.join(entity.path, _pubspec));
      var deps = <String>{};
      if (await pubspec.exists()) {
        final doc = loadYaml(await pubspec.readAsString());
        final section = doc is YamlMap ? doc['dependencies'] : null;
        deps = dependencyNames(section is YamlMap ? section : null);
      }
      result[p.basename(entity.path)] = deps;
    }
    return result;
  }

  /// Project-relative path (with '/') -> content for application Dart files.
  /// The CLI and bin entrypoint are tooling, not runtime code, so their catalog
  /// strings must not keep disabled application plugins active.
  Future<Map<String, String>> _appCodeFiles() async {
    final files = <String, String>{};
    final dir = Directory(p.join(root, 'lib'));
    if (!await dir.exists()) return files;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative =
          p.relative(entity.path, from: root).replaceAll('\\', '/');
      if (relative.startsWith('lib/cli/')) continue;
      files[relative] = await entity.readAsString();
    }
    return files;
  }

  /// Test files passed explicitly to `flutter test` by CI.
  Future<Map<String, String>> _testFiles() async {
    final files = <String, String>{};
    final dir = Directory(p.join(root, 'test'));
    if (!await dir.exists()) return files;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
      final relative =
          p.relative(entity.path, from: root).replaceAll('\\', '/');
      files[relative] = await entity.readAsString();
    }
    return files;
  }

  String _firstDifference(String before, String after) {
    final oldLines = before.split('\n');
    final newLines = after.split('\n');
    final count =
        oldLines.length < newLines.length ? oldLines.length : newLines.length;
    for (var index = 0; index < count; index++) {
      if (oldLines[index] != newLines[index]) {
        return 'line ${index + 1}: "${oldLines[index]}" -> "${newLines[index]}"';
      }
    }
    if (oldLines.length != newLines.length) {
      return 'line ${count + 1}: file length ${oldLines.length} -> '
          '${newLines.length} lines';
    }
    return 'content differs';
  }

  List<String> _plistKeys(String plist) {
    final keys = RegExp(r'<key>([^<]+)</key>');
    return [for (final m in keys.allMatches(plist)) m.group(1)!];
  }

  String _diff(List<String> before, List<String> after) {
    final added = after.where((e) => !before.contains(e)).toSet();
    final removed = before.where((e) => !after.contains(e)).toSet();
    if (added.isEmpty && removed.isEmpty) return 'no change';
    return [
      if (added.isNotEmpty) '+${added.join(', ')}',
      if (removed.isNotEmpty) '-${removed.join(', ')}',
    ].join('  ');
  }
}
