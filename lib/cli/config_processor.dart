// ignore_for_file: avoid_print
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'plugin_catalog.dart';
import 'plugin_registry_data.dart';
import 'safe_writer.dart';
import 'service_locator_gen.dart';

/// پردازشگر sweetmelon.yaml
/// خروجی: لیست پلاگین‌های فعال و فایل‌های generate شده
class ConfigProcessor {
  final String configPath;
  late final Map<String, bool> _enabledPlugins;

  /// sweetmelon.yaml is the single source of truth for plugins. Its `enabled`
  /// flags for the catalog plugins match the registrations the app ships with,
  /// and the golden test checks that rendering reproduces the committed file.
  static const bool serviceLocatorGeneratorEnabled = true;

  /// Maps a plugin id to its key in sweetmelon.yaml. Ids that are camelCase
  /// (e.g. `secureStorage` in service_locator.dart) become snake_case.
  static String yamlKeyFor(String pluginId) {
    const aliases = {'pdf': 'pdf_plugin'};
    if (aliases.containsKey(pluginId)) return aliases[pluginId]!;
    return pluginId.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => '_${m[0]!.toLowerCase()}',
    );
  }

  ConfigProcessor({this.configPath = 'sweetmelon.yaml'});

  /// خواندن config و parse
  Future<void> load() async {
    final file = File(configPath);

    if (!await file.exists()) {
      print('⚠️  sweetmelon.yaml not found, using defaults (all enabled)');
      _enabledPlugins = {
        for (final p in PluginRegistryData.allPlugins) p.id: true,
      };
      return;
    }

    final content = await file.readAsString();
    final yaml = loadYaml(content) as YamlMap;
    final plugins = yaml['plugins'] as YamlMap?;

    _enabledPlugins = {};

    for (final p in PluginRegistryData.allPlugins) {
      final pluginConfig = plugins?[yamlKeyFor(p.id)] as YamlMap?;
      final enabled = pluginConfig?['enabled'] as bool? ?? true;
      _enabledPlugins[p.id] = enabled;
    }
  }

  /// لیست پلاگین‌های فعال
  List<PluginDefinition> get enabledPlugins {
    return PluginRegistryData.allPlugins
        .where((p) => _enabledPlugins[p.id] == true)
        .toList();
  }

  /// لیست پلاگین‌های غیرفعال
  List<PluginDefinition> get disabledPlugins {
    return PluginRegistryData.allPlugins
        .where((p) => _enabledPlugins[p.id] != true)
        .toList();
  }

  /// Catalog of every plugin registration in service_locator.dart.
  static const String pluginCatalogPath = 'tool/plugin_catalog.json';
  static const String serviceLocatorPath = 'lib/di/service_locator.dart';

  /// Regenerates the plugin sections of service_locator.dart into [writer].
  ///
  /// The rendering is done by [renderServiceLocator]. A plugin with
  /// `enabled: false` in sweetmelon.yaml is left out. A plugin that is not
  /// listed counts as enabled. Nothing is written when the generator is
  /// switched off (see [serviceLocatorGeneratorEnabled]).
  Future<void> generateServiceLocator(SafeWriter writer) async {
    if (!serviceLocatorGeneratorEnabled) {
      print(
          '⛔ service_locator.dart NOT regenerated: generation is switched off '
          '(ConfigProcessor.serviceLocatorGeneratorEnabled). '
          'Plugin switches are not applied.');
      return;
    }

    final catalog = await PluginCatalog.load(pluginCatalogPath);
    if (catalog == null) {
      throw StateError('$pluginCatalogPath not found');
    }
    final yaml = loadYaml(await File(configPath).readAsString());
    final pluginsSection = yaml is YamlMap ? yaml['plugins'] as YamlMap? : null;

    final enabledKeys = <String>{
      for (final key in catalog.yamlKeys)
        if ((pluginsSection?[key] as YamlMap?)?['enabled'] as bool? ?? true)
          key,
    };

    final file = File(serviceLocatorPath);
    final before = await file.readAsString();
    final after = renderServiceLocator(
      before,
      catalog.entries,
      enabledKeys: enabledKeys,
    );
    writer.replace(serviceLocatorPath, after);
    print('✅ service_locator.dart: ${enabledKeys.length} of '
        '${catalog.yamlKeys.length} plugins enabled');
  }

  /// Generate dependency list for pubspec
  Future<void> generateDependencyReport() async {
    final enabled = enabledPlugins;
    final disabled = disabledPlugins;
    final deps = <String, String>{};

    for (final p in enabled) {
      deps.addAll(p.dependencies);
    }

    final removableDeps = <String, String>{};
    for (final p in disabled) {
      for (final dep in p.dependencies.entries) {
        // فقط اگه هیچ پلاگین فعال دیگه‌ای نیازش نداره
        final usedByOther = enabled.any(
          (ep) => ep.dependencies.containsKey(dep.key),
        );
        if (!usedByOther) {
          removableDeps[dep.key] = dep.value;
        }
      }
    }

    print('');
    print('📦 Dependency Report');
    print('────────────────────');
    print('');
    print('Required dependencies (${deps.length}):');
    for (final d in deps.entries) {
      print('  ✅ ${d.key}: ${d.value}');
    }

    if (removableDeps.isNotEmpty) {
      print('');
      print('Removable dependencies (${removableDeps.length}):');
      for (final d in removableDeps.entries) {
        print('  ❌ ${d.key}: ${d.value}');
      }
    }

    print('');
    print('Enabled plugins: ${enabled.length}');
    print('Disabled plugins: ${disabled.length}');
  }

  /// نمایش خلاصه
  void printSummary() {
    final enabled = enabledPlugins;
    final disabled = disabledPlugins;

    print('');
    print('🍈 Sweetmelon Plugin Configuration');
    print('═══════════════════════════════════');
    print('');
    print('✅ Enabled (${enabled.length}):');
    for (final p in enabled) {
      print('   • ${p.id.padRight(20)} — ${p.description}');
    }

    if (disabled.isNotEmpty) {
      print('');
      print('❌ Disabled (${disabled.length}):');
      for (final p in disabled) {
        print('   • ${p.id.padRight(20)} — ${p.description}');
      }
    }
  }
}
