import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/cli/plugin_catalog.dart';
import 'package:sweetmelon/cli/service_locator_gen.dart';
import 'package:yaml/yaml.dart';

Future<Set<String>> _enabledCatalogKeys(PluginCatalog catalog) async {
  final yaml = loadYaml(await File('sweetmelon.yaml').readAsString());
  final plugins = yaml is YamlMap ? yaml['plugins'] as YamlMap? : null;
  return {
    for (final key in catalog.yamlKeys)
      if ((plugins?[key] as YamlMap?)?['enabled'] as bool? ?? true) key,
  };
}

void main() {
  test('rendering yaml-enabled plugins reproduces service_locator.dart',
      () async {
    final catalog = await PluginCatalog.load('tool/plugin_catalog.json');
    expect(catalog, isNotNull);
    final source = await File('lib/di/service_locator.dart').readAsString();

    final rendered = renderServiceLocator(
      source,
      catalog!.entries,
      enabledKeys: await _enabledCatalogKeys(catalog),
    );

    expect(rendered, source);
  });

  test('a disabled plugin is removed from all three sections', () async {
    final catalog = await PluginCatalog.load('tool/plugin_catalog.json');
    final source = await File('lib/di/service_locator.dart').readAsString();
    final enabled = await _enabledCatalogKeys(catalog!);
    final target = catalog.entries.firstWhere(
        (entry) => entry.kind == 'lazy' && enabled.contains(entry.yamlKey));

    final rendered = renderServiceLocator(
      source,
      catalog.entries,
      enabledKeys: enabled.difference({target.yamlKey}),
    );

    expect(rendered,
        isNot(contains("import 'package:sweetmelon/${target.importPath}';")));
    expect(rendered, isNot(contains("id: '${target.id}'")));
  });

  test('network_info is cataloged so its JavaScript namespace can register',
      () async {
    final catalog = await PluginCatalog.load('tool/plugin_catalog.json');
    final entry = catalog!.entries
        .singleWhere((candidate) => candidate.yamlKey == 'network_info');
    expect(entry.kind, 'eager');
    expect(entry.code, 'NetworkInfoPlugin()');
  });

  test('imports use the package name it is given', () async {
    final catalog = await PluginCatalog.load('tool/plugin_catalog.json');
    final source = await File('lib/di/service_locator.dart').readAsString();
    final rendered = renderServiceLocator(
      source,
      catalog!.entries,
      enabledKeys: await _enabledCatalogKeys(catalog),
      packageName: 'my_app',
    );
    expect(rendered, contains("import 'package:my_app/plugins/"));
    expect(rendered, isNot(contains("import 'package:" 'sweetmelon/plugins/')));
  });
}
