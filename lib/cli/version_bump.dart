/// The version name (`2.4.0`) and the build number (`+7`) together.
class BuildVersion {
  const BuildVersion(this.name, this.build);

  final String name;
  final int build;

  /// The pubspec.yaml form, e.g. `2.4.0+7`.
  String get full => '$name+$build';
}

enum BumpKind { build, patch, minor, major }

final _nameRe = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

/// Returns the next version.
///
/// - [BumpKind.build]: the name stays, the build number goes up by one.
/// - patch, minor, major: the matching part goes up, lower parts reset to 0,
///   and the build number goes up by one. The build number never goes down.
BuildVersion bumpVersion({
  required String name,
  required int build,
  required BumpKind kind,
}) {
  final match = _nameRe.firstMatch(name);
  if (match == null) {
    throw FormatException('version "$name" must look like 1.2.3');
  }
  var major = int.parse(match.group(1)!);
  var minor = int.parse(match.group(2)!);
  var patch = int.parse(match.group(3)!);

  if (kind == BumpKind.major) {
    major++;
    minor = 0;
    patch = 0;
  } else if (kind == BumpKind.minor) {
    minor++;
    patch = 0;
  } else if (kind == BumpKind.patch) {
    patch++;
  }

  final newName = kind == BumpKind.build ? name : '$major.$minor.$patch';
  return BuildVersion(newName, build + 1);
}

/// Reads `version: 1.2.3+4` from a pubspec.yaml text. The build number is 0
/// when the `+` part is missing.
BuildVersion? readPubspecVersion(String pubspec) {
  final match =
      RegExp(r'^version:\s*([0-9.]+)(?:\+(\d+))?\s*$', multiLine: true)
          .firstMatch(pubspec);
  if (match == null) return null;
  return BuildVersion(match.group(1)!, int.parse(match.group(2) ?? '0'));
}

/// Replaces the `version:` line of a pubspec.yaml text.
String setPubspecVersion(String pubspec, BuildVersion version) {
  return pubspec.replaceFirst(
    RegExp(r'^version:.*$', multiLine: true),
    'version: ${version.full}',
  );
}

/// Replaces `  version:` inside the `project:` section of sweetmelon.yaml.
/// Returns [yaml] unchanged when the key is missing.
String setProjectVersion(String yaml, String name) {
  return yaml.replaceFirst(
    RegExp(r'^  version:.*$', multiLine: true),
    '  version: $name',
  );
}
