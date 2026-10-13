import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/cli/config_validator.dart';
import 'package:sweetmelon/cli/core_compat.dart';
import 'package:sweetmelon/cli/plugin_selection.dart';
import 'package:sweetmelon/cli/project_settings.dart';
import 'package:sweetmelon/core_version.dart';

void main() {
  group('checkCoreCompatibility', () {
    test('same minor is compatible', () {
      expect(checkCoreCompatibility('2.4', actual: '2.4.0'), isNull);
      expect(checkCoreCompatibility('2.4', actual: '2.4.7'), isNull);
    });

    test('patch requirement needs at least that patch', () {
      expect(checkCoreCompatibility('2.4.1', actual: '2.4.3'), isNull);
      expect(checkCoreCompatibility('2.4.3', actual: '2.4.1'), isNotNull);
    });

    test('a different minor or major is refused', () {
      expect(checkCoreCompatibility('2.4', actual: '2.5.0'), isNotNull);
      expect(checkCoreCompatibility('2.4', actual: '2.3.9'), isNotNull);
      expect(checkCoreCompatibility('2.4', actual: '3.4.0'), isNotNull);
    });

    test('malformed requirements are refused', () {
      expect(parseCoreRequirement('2'), isNull);
      expect(parseCoreRequirement('latest'), isNull);
      expect(checkCoreCompatibility('latest'), isNotNull);
    });
  });

  group('release files', () {
    test('CHANGELOG has a section for the current core version', () {
      final changelog = File('CHANGELOG.md').readAsStringSync();
      expect(changelog, contains('## [$sweetmelonCoreVersion]'));
    });

    test('sweetmelon.yaml pins the current minor', () {
      final core =
          ProjectSettings.readCore(File('sweetmelon.yaml').readAsStringSync());
      expect(core, isNotNull);
      expect(checkCoreCompatibility(core!), isNull);
    });
  });

  group('validator: new keys', () {
    const known = {'storage', 'camera'};
    List<ConfigIssue> run(String s) =>
        const ConfigValidator(knownPluginKeys: known).validate(s);
    // A complete valid file the cases below add one key to.
    const base = 'core: "2.4"\nproject:\n  name: a\n  version: 1.0.0\n'
        '  display_name: A\n';
    const tail = 'plugins:\n  storage:\n    enabled: true\n';
    bool hasError(List<ConfigIssue> l, String part) => l.any(
        (i) => i.severity == IssueSeverity.error && i.message.contains(part));

    test('missing core is a warning', () {
      final issues = run('project:\n  name: a\n');
      expect(
          issues.any((i) =>
              i.severity == IssueSeverity.warning &&
              i.message.contains('core')),
          isTrue);
    });

    test('incompatible core is an error', () {
      expect(hasError(run('core: "9.9"\n'), 'core'), isTrue);
    });

    test('dart_package and icon are checked', () {
      expect(
          hasError(run('core: "2.4"\nproject:\n  dart_package: Bad-Name\n'),
              'package'),
          isTrue);
      expect(hasError(run('core: "2.4"\nproject:\n  icon: logo.jpg\n'), 'icon'),
          isTrue);
      expect(run('${base}  dart_package: my_app\n  icon: a/b.png\n$tail'),
          isEmpty);
    });

    test('plugin_selection rules', () {
      expect(
          hasError(run('core: "2.4"\nplugin_selection:\n  mode: sometimes\n'),
              'mode'),
          isTrue);
      expect(
          hasError(run('core: "2.4"\nplugin_selection:\n  include: [nope]\n'),
              'unknown plugin'),
          isTrue);
      expect(
          hasError(
              run('core: "2.4"\nplugin_selection:\n  include: [camera]\n  exclude: [camera]\n'),
              'both'),
          isTrue);
      expect(
          run('${base}$tail'
              'plugin_selection:\n  mode: auto\n  include: [camera]\n  exclude: [storage]\n'),
          isEmpty);
    });
  });

  group('PluginSelection.fromYaml', () {
    test('defaults to manual without the section', () {
      final s = PluginSelection.fromYaml('core: "2.4"\n');
      expect(s.mode, SelectionMode.manual);
      expect(s.include, isEmpty);
    });

    test('reads mode, include and exclude', () {
      final s = PluginSelection.fromYaml(
          'plugin_selection:\n  mode: auto\n  include: [camera]\n  exclude: [nfc]\n');
      expect(s.mode, SelectionMode.auto);
      expect(s.include, ['camera']);
      expect(s.exclude, ['nfc']);
    });
  });
}
