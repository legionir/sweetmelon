import 'dart:convert';
import 'dart:io';

/// One plugin registration in lib/di/service_locator.dart.
///
/// The catalog file (tool/plugin_catalog.json) is the list of these entries.
class PluginCatalogEntry {
  const PluginCatalogEntry({
    required this.kind,
    required this.yamlKey,
    required this.importPath,
    required this.code,
    this.id,
  });

  factory PluginCatalogEntry.fromJson(Map<String, dynamic> json) {
    return PluginCatalogEntry(
      kind: json['kind'] as String,
      yamlKey: json['yamlKey'] as String,
      importPath: json['importPath'] as String,
      code: json['code'] as String,
      id: json['id'] as String?,
    );
  }

  /// `eager` plugins are registered at start-up, `lazy` ones on first use.
  final String kind;

  /// Key under `plugins:` in sweetmelon.yaml.
  final String yamlKey;

  /// Path below lib/, e.g. `plugins/camera/lib/camera_plugin.dart`.
  final String importPath;

  /// Constructor expression used for registration, e.g. `CameraPlugin()`.
  final String code;

  /// Lazy plugins only: the id used by the bridge, e.g. `secureStorage`.
  final String? id;

  bool get isLazy => kind == 'lazy';
}

class PluginCatalog {
  const PluginCatalog(this.entries);

  final List<PluginCatalogEntry> entries;

  Set<String> get yamlKeys => {for (final e in entries) e.yamlKey};

  List<PluginCatalogEntry> get eager =>
      entries.where((e) => e.kind == 'eager').toList();

  List<PluginCatalogEntry> get lazy =>
      entries.where((e) => e.kind == 'lazy').toList();

  /// Reads [path]. Returns null when the file does not exist, so callers can
  /// run without a catalog (for example in a project created by the CLI).
  static Future<PluginCatalog?> load(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
    return PluginCatalog([
      for (final item in decoded)
        PluginCatalogEntry.fromJson(item as Map<String, dynamic>),
    ]);
  }
}
