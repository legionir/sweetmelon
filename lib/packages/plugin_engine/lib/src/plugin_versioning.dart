/// نسخه semantic
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
  });

  factory SemanticVersion.parse(String version) {
    final cleaned = version.trim().replaceFirst(RegExp(r'^v'), '');
    String? preRelease;
    var versionPart = cleaned;

    if (cleaned.contains('-')) {
      final parts = cleaned.split('-');
      versionPart = parts[0];
      preRelease = parts.sublist(1).join('-');
    }

    final segments = versionPart.split('.');
    return SemanticVersion(
      major: segments.isNotEmpty ? int.tryParse(segments[0]) ?? 0 : 0,
      minor: segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0,
      patch: segments.length > 2 ? int.tryParse(segments[2]) ?? 0 : 0,
      preRelease: preRelease,
    );
  }

  bool get isPreRelease => preRelease != null;

  /// آیا این نسخه با requested سازگار هست؟
  bool satisfies(VersionConstraint constraint) {
    return constraint.allows(this);
  }

  /// آیا breaking change هست نسبت به نسخه دیگه؟
  bool isBreakingFrom(SemanticVersion other) {
    return major != other.major;
  }

  /// آیا minor change هست؟
  bool isMinorFrom(SemanticVersion other) {
    return major == other.major && minor != other.minor;
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    if (preRelease == null && other.preRelease != null) return 1;
    if (preRelease != null && other.preRelease == null) return -1;

    return 0;
  }

  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;
  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;
  bool operator <(SemanticVersion other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) {
    if (other is! SemanticVersion) return false;
    return major == other.major && minor == other.minor && patch == other.patch;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    return preRelease != null ? '$base-$preRelease' : base;
  }

  Map<String, dynamic> toJson() => {
        'major': major,
        'minor': minor,
        'patch': patch,
        if (preRelease != null) 'preRelease': preRelease,
        'string': toString(),
      };
}

/// محدودیت نسخه
abstract class VersionConstraint {
  bool allows(SemanticVersion version);
}

/// نسخه دقیق
class ExactVersion implements VersionConstraint {
  final SemanticVersion version;
  const ExactVersion(this.version);

  @override
  bool allows(SemanticVersion v) => v == version;
}

/// حداقل نسخه (>=)
class MinVersion implements VersionConstraint {
  final SemanticVersion minimum;
  const MinVersion(this.minimum);

  @override
  bool allows(SemanticVersion v) => v >= minimum;
}

/// بازه نسخه
class VersionRange implements VersionConstraint {
  final SemanticVersion? min;
  final SemanticVersion? max;
  final bool includeMin;
  final bool includeMax;

  const VersionRange({
    this.min,
    this.max,
    this.includeMin = true,
    this.includeMax = false,
  });

  @override
  bool allows(SemanticVersion v) {
    if (min != null) {
      if (includeMin && v < min!) return false;
      if (!includeMin && v <= min!) return false;
    }

    if (max != null) {
      if (includeMax && v > max!) return false;
      if (!includeMax && v >= max!) return false;
    }

    return true;
  }
}

/// Compatible with (^) — مثل semver caret
class CompatibleWith implements VersionConstraint {
  final SemanticVersion version;
  const CompatibleWith(this.version);

  @override
  bool allows(SemanticVersion v) {
    if (v < version) return false;
    return v.major == version.major;
  }
}

/// هر نسخه‌ای
class AnyVersion implements VersionConstraint {
  const AnyVersion();

  @override
  bool allows(SemanticVersion v) => true;
}

/// parse constraint string
VersionConstraint parseConstraint(String input) {
  final trimmed = input.trim();

  if (trimmed == '*' || trimmed == 'any') {
    return const AnyVersion();
  }

  if (trimmed.startsWith('^')) {
    return CompatibleWith(SemanticVersion.parse(trimmed.substring(1)));
  }

  if (trimmed.startsWith('>=')) {
    return MinVersion(SemanticVersion.parse(trimmed.substring(2)));
  }

  return ExactVersion(SemanticVersion.parse(trimmed));
}
