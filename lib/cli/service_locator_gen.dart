import 'plugin_catalog.dart';
import 'text_blocks.dart';

/// Rebuilds the three generated sections of lib/di/service_locator.dart.
///
/// - `plugin-imports`: one import per enabled plugin.
/// - `eager-plugins`: `registry.register(...)` for each enabled eager plugin.
/// - `lazy-plugins`: a `LazyPluginDefinition` for each enabled lazy plugin.
///
/// Everything outside the markers is kept as it is. [catalog] order is kept.
/// [enabledKeys] holds the yaml keys (see [PluginCatalogEntry.yamlKey]) of the
/// plugins that should be registered. A registration that is not in
/// [enabledKeys] is removed from the output.
///
/// Rendering the committed file with every catalog entry enabled gives the
/// committed file back. The golden test checks this.
/// Dart package name of the core as shipped. The generated imports use the
/// project's real name (see `rename --dart-package`); the name is never written
/// as a `package:` literal here, so a rename does not rewrite this file.
const defaultPackageName = 'sweetmelon';

String renderServiceLocator(
  String source,
  List<PluginCatalogEntry> catalog, {
  required Set<String> enabledKeys,
  String packageName = defaultPackageName,
}) {
  final enabled = [
    for (final entry in catalog)
      if (enabledKeys.contains(entry.yamlKey)) entry,
  ];
  final eager = enabled.where((e) => e.kind == 'eager').toList();
  final lazy = enabled.where((e) => e.kind == 'lazy').toList();

  var text = _block(source, 'plugin-imports', '', [
    for (final p in enabled) "import 'package:$packageName/${p.importPath}';",
  ]);
  text = _block(text, 'eager-plugins', '    ', [
    for (final p in eager) ...[
      'await registry.register(',
      '  ${p.code},',
      ');',
    ],
  ]);
  text = _block(text, 'lazy-plugins', '      ', [
    for (final p in lazy) ...[
      'LazyPluginDefinition(',
      "  id: '${p.id}',",
      "  version: '1.0.0',",
      '  factory: () => ${p.code},',
      '),',
    ],
  ]);
  return text;
}

String _block(String text, String name, String indent, List<String> body) {
  return replaceMarkedBlock(
    text,
    name: name,
    openTag: '// <sweetmelon:$name>',
    closeTag: '// </sweetmelon:$name>',
    indent: indent,
    body: body,
  );
}
