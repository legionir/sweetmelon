import 'package:yaml/yaml.dart';

import 'config_validator.dart';
import 'icon_generator.dart';
import 'package_rename.dart';
import 'project_settings.dart';
import 'version_bump.dart';

enum DoctorLevel { ok, warn, fail }

class DoctorFinding {
  const DoctorFinding(this.level, this.area, this.message, {this.hint});

  final DoctorLevel level;
  final String area;
  final String message;
  final String? hint;

  @override
  String toString() {
    final tag = switch (level) {
      DoctorLevel.ok => 'OK  ',
      DoctorLevel.warn => 'WARN',
      DoctorLevel.fail => 'FAIL',
    };
    final hintText = hint == null ? '' : '\n      hint: $hint';
    return '$tag $area: $message$hintText';
  }
}

/// What the doctor knows about the project. The runner reads the files and
/// fills this in. A null text means the file does not exist.
class ProjectSnapshot {
  const ProjectSnapshot({
    required this.paths,
    this.yaml,
    this.pubspec,
    this.gradle,
    this.googleServices,
    this.catalogKeys,
    this.registeredPluginKeys,
    this.pluginDirs,
    this.syncWarnings = const [],
    this.pendingSync = const [],
  });

  /// Every project-relative path (with '/') that exists.
  final Set<String> paths;
  final String? yaml;
  final String? pubspec;
  final String? gradle;
  final String? googleServices;

  /// Plugin keys from tool/plugin_catalog.json. Null when the catalog is
  /// missing.
  final Set<String>? catalogKeys;

  /// Plugin keys currently imported by lib/di/service_locator.dart. This is
  /// distinct from [catalogKeys]: a catalog entry is available to configure,
  /// but is not necessarily registered in the selected build.
  final Set<String>? registeredPluginKeys;

  /// Folder names under lib/plugins. Null when the folder cannot be read.
  final Set<String>? pluginDirs;

  /// Warnings from the sync plan, for example a disabled plugin that is still
  /// imported.
  final List<String> syncWarnings;

  /// Files from the sync plan that differ from what sweetmelon.yaml says.
  final List<String> pendingSync;
}

/// Runs every doctor check on [snapshot]. Pure: it reads nothing from disk.
List<DoctorFinding> checkProject(ProjectSnapshot snapshot) {
  final findings = <DoctorFinding>[];

  // sweetmelon.yaml
  final yaml = snapshot.yaml;
  ProjectSettings? settings;
  if (yaml == null) {
    findings.add(const DoctorFinding(
      DoctorLevel.fail,
      'sweetmelon.yaml',
      'file not found',
      hint: 'Run: dart run bin/sweetmelon.dart create project <name>',
    ));
  } else {
    final issues =
        ConfigValidator(knownPluginKeys: snapshot.catalogKeys).validate(yaml);
    if (issues.isEmpty) {
      findings
          .add(const DoctorFinding(DoctorLevel.ok, 'sweetmelon.yaml', 'valid'));
    }
    for (final issue in issues) {
      findings.add(DoctorFinding(
        issue.isError ? DoctorLevel.fail : DoctorLevel.warn,
        'sweetmelon.yaml',
        issue.toString(),
      ));
    }
    settings = _settingsOrNull(yaml);
    if (settings == null) {
      findings.add(const DoctorFinding(DoctorLevel.fail, 'sweetmelon.yaml',
          'could not read project section'));
    }
  }

  if (snapshot.catalogKeys == null) {
    findings.add(const DoctorFinding(
      DoctorLevel.warn,
      'plugin catalog',
      'tool/plugin_catalog.json not found: plugin keys are not checked',
    ));
  }

  // plugins: sweetmelon.yaml against the configured service locator. The
  // catalog is only the set of available plugins; it is not a registration.
  final catalogKeys = snapshot.catalogKeys;
  final registeredKeys = snapshot.registeredPluginKeys;
  final flags = yaml == null ? const <String, bool>{} : enabledFlags(yaml);
  if (yaml != null && catalogKeys != null) {
    for (final key in flags.keys) {
      if (flags[key] == true && !catalogKeys.contains(key)) {
        findings.add(DoctorFinding(
          DoctorLevel.fail,
          'plugins',
          '"$key" is enabled in sweetmelon.yaml but is missing from the plugin catalog',
          hint: 'Add it to tool/plugin_catalog.json, or set it to false',
        ));
      }
    }
  }
  if (yaml != null && registeredKeys != null) {
    for (final key in flags.keys) {
      if (flags[key] == true && !registeredKeys.contains(key)) {
        findings.add(DoctorFinding(
          DoctorLevel.fail,
          'plugins',
          '"$key" is enabled in sweetmelon.yaml but service_locator.dart does not register it',
          hint: 'Run: dart run bin/sweetmelon.dart sync --apply',
        ));
      }
    }
    for (final key in registeredKeys) {
      if (flags[key] == false) {
        findings.add(DoctorFinding(
          DoctorLevel.fail,
          'plugins',
          '"$key" is registered in service_locator.dart but disabled in sweetmelon.yaml',
          hint: 'Run: dart run bin/sweetmelon.dart sync --apply',
        ));
      }
    }
  }
  final dirs = snapshot.pluginDirs;
  if (yaml != null && dirs != null) {
    for (final dir in dirs.toList()..sort()) {
      if (!flags.containsKey(dir)) {
        findings.add(DoctorFinding(
          DoctorLevel.warn,
          'plugins',
          'lib/plugins/$dir has no entry in sweetmelon.yaml',
          hint: 'Add it under plugins: with enabled: true or false',
        ));
      }
    }
  }

  // application id
  final gradleId = snapshot.gradle == null
      ? null
      : readGradleApplicationId(snapshot.gradle!);
  final yamlId = settings?.applicationId;
  if (gradleId == null) {
    findings.add(const DoctorFinding(
      DoctorLevel.fail,
      'application id',
      'applicationId not found in android/app/build.gradle.kts',
    ));
  } else if (gradleId.startsWith('com.example')) {
    findings.add(DoctorFinding(
      DoctorLevel.fail,
      'application id',
      '$gradleId is the template default',
      hint:
          'Run: dart run bin/sweetmelon.dart rename --id com.acme.app --apply',
    ));
  }
  if (yamlId == null) {
    findings.add(const DoctorFinding(
      DoctorLevel.warn,
      'application id',
      'project.application_id is not set in sweetmelon.yaml',
      hint: 'Add application_id under project:',
    ));
  } else if (gradleId != null && gradleId != yamlId) {
    findings.add(DoctorFinding(
      DoctorLevel.fail,
      'application id',
      'sweetmelon.yaml says $yamlId but build.gradle.kts says $gradleId',
      hint: 'Run: dart run bin/sweetmelon.dart rename --apply',
    ));
  } else if (gradleId != null) {
    findings.add(DoctorFinding(DoctorLevel.ok, 'application id', gradleId));
  }
  if (gradleId != null) {
    final problem = validateApplicationId(gradleId);
    if (problem != null && !gradleId.startsWith('com.example')) {
      findings.add(DoctorFinding(DoctorLevel.warn, 'application id', problem));
    }
  }

  // version
  final pubspec = snapshot.pubspec;
  if (pubspec != null && settings != null) {
    final pubVersion = readPubspecVersion(pubspec);
    if (pubVersion == null) {
      findings.add(const DoctorFinding(
          DoctorLevel.fail, 'version', 'pubspec.yaml has no version line'));
    } else if (settings.version.isNotEmpty &&
        pubVersion.name != settings.version) {
      findings.add(DoctorFinding(
        DoctorLevel.fail,
        'version',
        'pubspec.yaml ${pubVersion.name} differs from project.version '
            '${settings.version}',
        hint: 'Run: dart run bin/sweetmelon.dart sync --apply',
      ));
    } else {
      findings.add(DoctorFinding(DoctorLevel.ok, 'version', pubVersion.full));
    }
  }

  // icons
  final missingAndroid = [
    for (final target in iconTargets())
      if (target.path.startsWith('android/') &&
          !snapshot.paths.contains(target.path))
        target.path,
  ];
  if (missingAndroid.isEmpty) {
    findings.add(const DoctorFinding(
        DoctorLevel.ok, 'Android icons', 'all mipmap icons present'));
  } else {
    findings.add(DoctorFinding(
      DoctorLevel.fail,
      'Android icons',
      '${missingAndroid.length} mipmap icon(s) missing',
      hint: 'Run: dart run bin/sweetmelon.dart icon <source.png>',
    ));
  }
  const contentsPath = '$iosAppIconDir/Contents.json';
  if (snapshot.paths.contains(contentsPath)) {
    findings.add(const DoctorFinding(
        DoctorLevel.ok, 'iOS icons', 'AppIcon Contents.json present'));
  } else {
    findings.add(const DoctorFinding(
      DoctorLevel.fail,
      'iOS icons',
      '$contentsPath is missing',
      hint: 'Run: dart run bin/sweetmelon.dart icon <source.png>',
    ));
  }

  // Firebase
  final services = snapshot.googleServices;
  if (services != null && services.contains('YOUR_')) {
    findings.add(const DoctorFinding(
      DoctorLevel.warn,
      'Firebase',
      'google-services.json still has placeholder values',
      hint: 'Download the file from the Firebase console',
    ));
  }

  // signing
  if (!snapshot.paths.contains('android/key.properties')) {
    findings.add(const DoctorFinding(
      DoctorLevel.warn,
      'signing',
      'android/key.properties not found: release builds use debug signing',
      hint: 'Create it from a stable keystore (never commit it)',
    ));
  }

  // plugins and sync
  for (final message in snapshot.syncWarnings) {
    findings.add(DoctorFinding(DoctorLevel.warn, 'plugins', message));
  }
  if (snapshot.pendingSync.isEmpty) {
    findings.add(const DoctorFinding(
        DoctorLevel.ok, 'sync', 'native files match sweetmelon.yaml'));
  } else {
    for (final message in snapshot.pendingSync) {
      findings.add(DoctorFinding(
        DoctorLevel.fail,
        'sync',
        message,
        hint: 'Run: dart run bin/sweetmelon.dart sync --apply',
      ));
    }
  }

  return findings;
}

/// The `enabled` flag of every entry under `plugins:`. A missing flag counts as
/// true. Returns an empty map when the file cannot be read.
Map<String, bool> enabledFlags(String yaml) {
  try {
    final doc = loadYaml(yaml);
    final plugins = doc is YamlMap ? doc['plugins'] : null;
    final out = <String, bool>{};
    if (plugins is YamlMap) {
      for (final entry in plugins.entries) {
        final settings = entry.value;
        final flag = settings is YamlMap ? settings['enabled'] : null;
        out[entry.key.toString()] = flag is bool ? flag : true;
      }
    }
    return out;
  } on Exception {
    return const {};
  }
}

ProjectSettings? _settingsOrNull(String yaml) {
  try {
    return ProjectSettings.fromYaml(yaml);
  } on Exception {
    return null;
  }
}
