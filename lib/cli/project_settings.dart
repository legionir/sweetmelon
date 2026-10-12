import 'package:yaml/yaml.dart';

/// Values from the `project:` section of sweetmelon.yaml.
class ProjectSettings {
  const ProjectSettings({
    required this.name,
    required this.displayName,
    required this.version,
    this.applicationId,
  });

  final String name;
  final String displayName;

  /// Version name without build number, e.g. `2.4.0`. A `+n` suffix in the
  /// yaml is dropped: the build number lives in pubspec.yaml.
  final String version;

  /// Android applicationId and iOS bundle id, e.g. `com.acme.app`. Null when
  /// the key is not set.
  final String? applicationId;

  /// Reads the `project:` section. Missing values are empty strings.
  static ProjectSettings fromYaml(String text) {
    final doc = loadYaml(text);
    final project = doc is YamlMap ? doc['project'] : null;

    String read(String key) {
      final value = project is YamlMap ? project[key] : null;
      return value == null ? '' : value.toString().trim();
    }

    final appId = read('application_id');
    return ProjectSettings(
      name: read('name'),
      displayName: read('display_name'),
      version: read('version').split('+').first,
      applicationId: appId.isEmpty ? null : appId,
    );
  }
}

/// Sets `project.application_id` in sweetmelon.yaml text. Replaces the line
/// when it exists; otherwise adds it under `project:` after `version:`.
/// Returns [yaml] unchanged when neither line is found.
String setProjectApplicationId(String yaml, String id) {
  final existing = RegExp(r'^  application_id:.*$', multiLine: true);
  if (existing.hasMatch(yaml)) {
    return yaml.replaceFirst(existing, '  application_id: $id');
  }
  return yaml.replaceFirstMapped(
    RegExp(r'^  version:.*$', multiLine: true),
    (m) => '${m[0]!}\n  application_id: $id',
  );
}
