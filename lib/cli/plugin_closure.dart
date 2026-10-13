/// Works out which plugins the app really uses.
///
/// A plugin directory under lib/plugins stays active when sweetmelon.yaml
/// enables it (a missing entry counts as enabled), when build code imports it,
/// or when an active plugin declares it as a local path dependency. That
/// transitive closure means a plugin can safely depend on another plugin.
///
/// Test files and the CLI implementation are not part of the application
/// build, so an import there does not keep a disabled plugin active.
class PluginClosure {
  PluginClosure._(this.activeDirs, this.neededPackages, this.importedBy);

  /// Plugin directory names that stay in the build.
  final Set<String> activeDirs;

  /// Packages needed by active plugins and by code outside disabled plugins.
  final Set<String> neededPackages;

  /// Plugin directories kept only because of an import or a local dependency:
  /// dir -> first source that needs it. Used to explain unexpected retention.
  final Map<String, String> importedBy;

  /// Matches only real import/export directives, never a path in a comment or
  /// a string literal (such as plugin_registry_data.dart's catalog strings).
  static final _pluginImport = RegExp(
    r'''^\s*(?:import|export)\s+['"]package:[a-z0-9_]+/plugins/([a-z0-9_]+)/''',
    multiLine: true,
  );
  static final _packageImport = RegExp(
    r'''^\s*(?:import|export)\s+['"]package:([a-z0-9_]+)/''',
    multiLine: true,
  );

  /// [files]: project-relative path with '/' separators -> content, for Dart
  /// files that are part of the application build.
  /// [pluginDeps]: plugin directory name -> packages from its pubspec.yaml.
  /// A dependency whose name is another plugin directory is a transitive local
  /// plugin dependency and is retained even when no Dart import references it.
  /// [enabled]: plugin directory name -> flag from sweetmelon.yaml.
  factory PluginClosure.compute({
    required Map<String, String> files,
    required Map<String, Set<String>> pluginDeps,
    required Map<String, bool> enabled,
  }) {
    final allDirs = pluginDeps.keys.toSet();
    final active = <String>{
      for (final dir in allDirs)
        if (enabled[dir] ?? true) dir,
    };
    final importedBy = <String, String>{};

    var changed = true;
    while (changed) {
      changed = false;

      // Plugin pubspec path dependencies are part of the same application
      // closure. For example, safe_area can retain qr_scanner until its own
      // implementation no longer needs it.
      for (final owner in active.toList()) {
        for (final dependency in pluginDeps[owner] ?? const <String>{}) {
          if (allDirs.contains(dependency) && active.add(dependency)) {
            importedBy[dependency] = 'lib/plugins/$owner/pubspec.yaml';
            changed = true;
          }
        }
      }

      for (final entry in files.entries) {
        if (!_inScope(entry.key, active, allDirs)) continue;
        for (final match in _pluginImport.allMatches(entry.value)) {
          final dir = match.group(1)!;
          if (allDirs.contains(dir) && active.add(dir)) {
            importedBy[dir] = entry.key;
            changed = true;
          }
        }
      }
    }

    final needed = <String>{};
    for (final dir in active) {
      needed.addAll(pluginDeps[dir] ?? const <String>{});
    }
    for (final entry in files.entries) {
      if (!_inScope(entry.key, active, allDirs)) continue;
      for (final match in _packageImport.allMatches(entry.value)) {
        needed.add(match.group(1)!);
      }
    }

    return PluginClosure._(active, needed, importedBy);
  }

  /// A file belongs to the build unless it lives in a plugin directory that is
  /// not active.
  static bool _inScope(String path, Set<String> active, Set<String> allDirs) {
    const prefix = 'lib/plugins/';
    if (!path.startsWith(prefix)) return true;
    final dir = path.substring(prefix.length).split('/').first;
    return !allDirs.contains(dir) || active.contains(dir);
  }
}

/// Packages declared under `dependencies:` in a pubspec.yaml text, as a set.
/// The caller passes the parsed `dependencies` map, so this file has no YAML
/// import.
Set<String> dependencyNames(Map<dynamic, dynamic>? dependencies) {
  if (dependencies == null) return <String>{};
  return {for (final key in dependencies.keys) key.toString()};
}
