import '../core_version.dart';

/// A `core:` value from sweetmelon.yaml: `2.4` or `2.4.1`.
class CoreRequirement {
  const CoreRequirement(this.major, this.minor, [this.patch]);

  final int major;
  final int minor;

  /// Null when the value names only major and minor.
  final int? patch;

  @override
  String toString() => patch == null ? '$major.$minor' : '$major.$minor.$patch';
}

final _requirementRe = RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?$');
final _versionRe = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

/// Parses `2.4` or `2.4.1`. Returns null for anything else.
CoreRequirement? parseCoreRequirement(String value) {
  final match = _requirementRe.firstMatch(value.trim());
  if (match == null) return null;
  return CoreRequirement(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    match.group(3) == null ? null : int.parse(match.group(3)!),
  );
}

/// Checks a project's `core:` value against the core that is running.
///
/// Compatible means: same major and minor version, and a patch number that is
/// at least the required one (when the requirement names a patch). A new minor
/// or major version of the core is never picked up silently: the project has
/// to be moved to it on purpose.
///
/// Returns null when compatible, otherwise a message.
String? checkCoreCompatibility(
  String required, {
  String actual = sweetmelonCoreVersion,
}) {
  final want = parseCoreRequirement(required);
  if (want == null) {
    return 'core "$required" must look like 2.4 or 2.4.1';
  }
  final have = _versionRe.firstMatch(actual);
  if (have == null) return 'core version "$actual" is not valid';
  final major = int.parse(have.group(1)!);
  final minor = int.parse(have.group(2)!);
  final patch = int.parse(have.group(3)!);

  if (want.major != major || want.minor != minor) {
    return 'this project needs core ${want.major}.${want.minor}, but the '
        'core in use is $actual. Use a ${want.major}.${want.minor}.x release '
        'of the core, or change "core:" in sweetmelon.yaml after checking the '
        'changelog';
  }
  if (want.patch != null && patch < want.patch!) {
    return 'this project needs core $want or newer, but the core in use is '
        '$actual';
  }
  return null;
}
