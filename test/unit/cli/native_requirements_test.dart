import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/cli/plugin_native_requirements.dart';
import 'package:sweetmelon/cli/plugin_registry_data.dart';
import 'package:yaml/yaml.dart';

Set<String> _pluginDirs() => {
      for (final entity in Directory('lib/plugins').listSync())
        if (entity is Directory) entity.uri.pathSegments.reversed.skip(1).first,
    };

void main() {
  final dirs = _pluginDirs();
  final fromRegistry = {for (final p in PluginRegistryData.allPlugins) p.id};
  final fromTable = PluginNativeRequirementsData.byPlugin.keys.toSet();

  test('every plugin has native requirements in exactly one table', () {
    expect(dirs, isNotEmpty);
    expect(dirs.difference(fromRegistry.union(fromTable)), isEmpty,
        reason: 'plugins without an entry in either table');
    expect(fromRegistry.intersection(fromTable), isEmpty,
        reason: 'plugins described in both tables');
  });

  test('the tables only name plugins that exist', () {
    final unknownInTable = fromTable.difference(dirs);
    expect(unknownInTable, isEmpty);
    // PluginRegistryData still has a legacy `pdf` entry for pdf_plugin.
    expect(fromRegistry.difference(dirs), everyElement(equals('pdf')));
  });

  test('every plugin is cataloged and listed in sweetmelon.yaml', () {
    final catalog =
        (jsonDecode(File('tool/plugin_catalog.json').readAsStringSync())
                as List)
            .map((e) => (e as Map)['yamlKey'] as String)
            .toSet();
    final yaml =
        loadYaml(File('sweetmelon.yaml').readAsStringSync()) as YamlMap;
    final listed = (yaml['plugins'] as YamlMap).keys.cast<String>().toSet();

    expect(dirs.difference(catalog), isEmpty,
        reason: 'plugins missing from tool/plugin_catalog.json');
    expect(catalog.difference(dirs), isEmpty);
    expect(dirs.difference(listed), isEmpty,
        reason: 'plugins missing from sweetmelon.yaml');
  });

  test('entries look like real Android permissions and iOS usage keys', () {
    for (final requirement in allNativeRequirements()) {
      for (final permission in requirement.androidPermissions) {
        expect(
          permission.startsWith('android.permission.') ||
              permission == 'com.android.vending.BILLING',
          isTrue,
          reason: '${requirement.id}: $permission',
        );
      }
      for (final feature in requirement.androidFeatures) {
        expect(feature, startsWith('android.hardware.'),
            reason: requirement.id);
      }
      requirement.iosUsageDescriptions.forEach((key, text) {
        expect(key, matches(RegExp(r'^NS[A-Za-z]+UsageDescription$')),
            reason: requirement.id);
        expect(text.trim(), isNotEmpty, reason: '${requirement.id}: $key');
      });
    }
  });

  test('a plugin that uses the camera asks for the camera permission', () {
    for (final id in ['camera', 'camera_preview', 'document_scanner']) {
      final requirement =
          allNativeRequirements().singleWhere((r) => r.id == id);
      expect(
          requirement.androidPermissions, contains('android.permission.CAMERA'),
          reason: id);
      expect(requirement.iosUsageDescriptions,
          contains('NSCameraUsageDescription'),
          reason: id);
    }
  });
}
