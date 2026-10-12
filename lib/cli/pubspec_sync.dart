/// Result of [removeUnusedDependencies].
class PubspecSyncResult {
  const PubspecSyncResult(this.text, this.removed);

  /// The new pubspec.yaml content.
  final String text;

  /// Packages that were removed from `dependencies:`, in file order.
  final List<String> removed;
}

/// Removes packages from the `dependencies:` section of a pubspec.yaml text.
///
/// A package is removed only when:
/// - a disabled plugin declares it ([disabledPluginDeps]), and
/// - nothing that stays in the build needs it ([neededPackages]).
///
/// Only `dependencies:` is edited. `dev_dependencies:` and comments are kept
/// as they are. The edit works line by line, so the file keeps its layout.
PubspecSyncResult removeUnusedDependencies(
  String text, {
  required Set<String> disabledPluginDeps,
  required Set<String> neededPackages,
}) {
  final topLevel = RegExp(r'^[^\s#]');
  final depLine = RegExp(r'^  ([a-z0-9_]+):');

  final out = <String>[];
  final removed = <String>[];
  var inDependencies = false;
  var skippingEntry = false;

  for (final line in text.split('\n')) {
    if (topLevel.hasMatch(line)) {
      inDependencies = line.startsWith('dependencies:');
      skippingEntry = false;
    }

    if (skippingEntry) {
      // Nested lines of a removed entry (for example `    sdk: flutter`).
      if (line.startsWith('    ')) continue;
      skippingEntry = false;
    }

    if (inDependencies) {
      final match = depLine.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!;
        if (disabledPluginDeps.contains(name) &&
            !neededPackages.contains(name)) {
          removed.add(name);
          skippingEntry = true;
          continue;
        }
      }
    }

    out.add(line);
  }

  return PubspecSyncResult(out.join('\n'), removed);
}
