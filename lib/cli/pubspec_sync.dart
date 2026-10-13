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

/// Result of [addMissingDependencies].
class PubspecAddResult {
  const PubspecAddResult(this.text, this.added);

  /// The new pubspec.yaml content.
  final String text;

  /// Packages that were added to `dependencies:`, in the order they were
  /// written.
  final List<String> added;
}

/// Adds packages to the end of the `dependencies:` section of a pubspec.yaml
/// text.
///
/// [wanted] maps a package name to its version constraint. A package that is
/// already declared in `dependencies:` or `dev_dependencies:` is left alone,
/// whatever its constraint, so the call is idempotent and never overrides a
/// choice made by hand. Packages are written sorted by name, below a comment
/// that says where they came from.
///
/// Returns the text unchanged when there is no `dependencies:` section.
PubspecAddResult addMissingDependencies(
  String text, {
  required Map<String, String> wanted,
}) {
  final topLevel = RegExp(r'^[^\s#]');
  final depLine = RegExp(r'^  ([a-z0-9_]+):');

  final lines = text.split('\n');
  final declared = <String>{};
  var section = '';
  var depsStart = -1;
  var depsEnd = -1; // Index of the last non-blank line of `dependencies:`.

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (topLevel.hasMatch(line)) {
      section = line.split(':').first;
      if (section == 'dependencies') depsStart = i;
      continue;
    }
    if (section != 'dependencies' && section != 'dev_dependencies') continue;
    final match = depLine.firstMatch(line);
    if (match != null) declared.add(match.group(1)!);
    if (section == 'dependencies' && line.trim().isNotEmpty) depsEnd = i;
  }

  if (depsStart < 0) return PubspecAddResult(text, const <String>[]);
  if (depsEnd < depsStart) depsEnd = depsStart;

  final added = wanted.keys.where((name) => !declared.contains(name)).toList()
    ..sort();
  if (added.isEmpty) return PubspecAddResult(text, const <String>[]);

  final insert = <String>[
    '',
    '  # Added by `sweetmelon sync` for enabled plugins',
    for (final name in added) '  $name: ${wanted[name]}',
  ];
  lines.insertAll(depsEnd + 1, insert);
  return PubspecAddResult(lines.join('\n'), added);
}
