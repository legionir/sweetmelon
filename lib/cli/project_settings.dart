import 'package:yaml/yaml.dart';

/// Values from the `project:` section of sweetmelon.yaml.
class ProjectSettings {
  const ProjectSettings({
    required this.name,
    required this.displayName,
    required this.version,
    this.applicationId,
    this.dartPackage,
    this.icon,
  });

  final String name;
  final String displayName;

  /// Version name without build number, e.g. `2.4.0`. A `+n` suffix in the
  /// yaml is dropped: the build number lives in pubspec.yaml.
  final String version;

  /// Android applicationId and iOS bundle id, e.g. `com.acme.app`. Null when
  /// the key is not set.
  final String? applicationId;

  /// Dart package name (`name:` in pubspec.yaml), e.g. `my_app`. Null when the
  /// key is not set.
  final String? dartPackage;

  /// Path of the app icon (a square PNG of 1024 px or more), relative to the
  /// folder of sweetmelon.yaml. Null when the key is not set.
  final String? icon;

  /// The `core:` value (`2.4` or `2.4.1`), or null when the file has none.
  static String? readCore(String text) {
    final doc = loadYaml(text);
    final value = doc is YamlMap ? doc['core'] : null;
    return value?.toString().trim();
  }

  /// Reads the `project:` section. Missing values are empty strings.
  static ProjectSettings fromYaml(String text) {
    final doc = loadYaml(text);
    final project = doc is YamlMap ? doc['project'] : null;

    String read(String key) {
      final value = project is YamlMap ? project[key] : null;
      return value == null ? '' : value.toString().trim();
    }

    final appId = read('application_id');
    final dartPackage = read('dart_package');
    final icon = read('icon');
    return ProjectSettings(
      name: read('name'),
      displayName: read('display_name'),
      version: read('version').split('+').first,
      applicationId: appId.isEmpty ? null : appId,
      dartPackage: dartPackage.isEmpty ? null : dartPackage,
      icon: icon.isEmpty ? null : icon,
    );
  }
}

/// Sets `project.<key>` in sweetmelon.yaml text. Replaces the line when it
/// exists; otherwise adds it under `project:` after `version:`. Returns [yaml]
/// unchanged when neither line is found.
String setProjectKey(String yaml, String key, String value) {
  final existing = RegExp('^  ${RegExp.escape(key)}:.*\$', multiLine: true);
  if (existing.hasMatch(yaml)) {
    return yaml.replaceFirst(existing, '  $key: $value');
  }
  return yaml.replaceFirstMapped(
    RegExp(r'^  version:.*$', multiLine: true),
    (m) => '${m[0]!}\n  $key: $value',
  );
}

/// Sets `project.application_id` in sweetmelon.yaml text (see [setProjectKey]).
String setProjectApplicationId(String yaml, String id) =>
    setProjectKey(yaml, 'application_id', id);

/// Sets `plugins.<key>.enabled` in sweetmelon.yaml text. A plugin without an
/// `enabled:` line is added right below `plugins:` when [addIfMissing] is set,
/// otherwise [yaml] is returned unchanged.
String setPluginEnabled(String yaml, String key, bool enabled,
    {bool addIfMissing = false}) {
  final pattern = RegExp(
    '(^  ${RegExp.escape(key)}:[ \\t]*(?:#.*)?\\r?\\n(?:[ \\t]*(?:#.*)?\\r?\\n)*?    enabled:[ \\t]*)(true|false)',
    multiLine: true,
  );
  if (pattern.hasMatch(yaml)) {
    return yaml.replaceFirstMapped(pattern, (m) => '${m[1]}$enabled');
  }
  if (!addIfMissing) return yaml;
  final header =
      RegExp(r'^plugins:[ \t]*(?:\{\})?[ \t]*(?:#.*)?\r?\n', multiLine: true);
  final entry = '  $key:\n    enabled: $enabled\n';
  return yaml.replaceFirstMapped(header,
      (m) => m[0]!.contains('{}') ? 'plugins:\n$entry' : '${m[0]}$entry');
}
