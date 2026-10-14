import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sweetmelon/cli/app_scaffold.dart';
import 'package:sweetmelon/cli/config_validator.dart';
import 'package:sweetmelon/cli/plugin_catalog.dart';
import 'package:sweetmelon/cli/plugin_detect.dart';
import 'package:sweetmelon/core_version.dart';

void main() {
  late String workflow;
  setUpAll(() => workflow = File(workflowExamplePath).readAsStringSync());

  Map<String, String> template() => renderAppTemplate(
        appName: 'Notes',
        applicationId: 'com.acme.notes',
        dartPackage: 'notes',
        workflow: workflow,
      );

  test('the generated sweetmelon.yaml passes the validator', () async {
    final catalog = await PluginCatalog.load('tool/plugin_catalog.json');
    final issues = ConfigValidator(knownPluginKeys: catalog!.yamlKeys)
        .validate(template()['sweetmelon.yaml']!);
    expect(issues.where((i) => i.isError), isEmpty);
  });

  test('the workflow is pinned to the core version of this CLI', () {
    final text = template()['.github/workflows/build.yml']!;
    expect(text, contains('legionir/sweetmelon@v$sweetmelonCoreVersion'));
    expect(RegExp(r'legionir/sweetmelon@v').allMatches(text).length, 3);
  });

  test('the sample page uses storage and toast, which detect finds', () async {
    final catalog = await PluginCatalog.load('tool/plugin_catalog.json');
    final result = detectPlugins(
      files: {'main.js': template()['www/js/main.js']!},
      bridgeToKey: await bridgeNames('.', catalog!),
      namespaceToBridge:
          sdkNamespaces(File('assets/www/js/native-sdk.js').readAsStringSync()),
    );
    expect(result.plugins, {'storage', 'toast'});
    expect(result.dynamicUses, isEmpty);
  });

  group('InitRunner', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('init_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes the files only with apply', () async {
      final target = p.join(dir.path, 'app');
      expect(
          await InitRunner()
              .run(target, appName: 'Notes', applicationId: 'com.acme.notes'),
          0);
      expect(Directory(target).existsSync(), isFalse);
      expect(
          await InitRunner().run(target,
              appName: 'Notes', applicationId: 'com.acme.notes', apply: true),
          0);
      expect(File(p.join(target, 'www/index.html')).existsSync(), isTrue);
    });

    test('refuses a folder that is not empty and a bad id', () async {
      File(p.join(dir.path, 'x.txt')).writeAsStringSync('x');
      expect(
          await InitRunner().run(dir.path,
              appName: 'N', applicationId: 'com.acme.n', apply: true),
          1);
      expect(
          await InitRunner().run(p.join(dir.path, 'a'),
              appName: 'N', applicationId: 'nodots', apply: true),
          1);
    });
  });

  group('UpgradeRunner', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('upgrade_test');
      template().forEach((path, text) {
        File(p.join(dir.path, path))
          ..createSync(recursive: true)
          ..writeAsStringSync(text.replaceAll(
              'legionir/sweetmelon@v$sweetmelonCoreVersion',
              'legionir/sweetmelon@v2.5.0'));
      });
    });
    tearDown(() => dir.deleteSync(recursive: true));

    String workflowText() =>
        File(p.join(dir.path, '.github/workflows/build.yml'))
            .readAsStringSync();

    test('a patch release changes the pins', () async {
      expect(await UpgradeRunner(root: dir.path).run('2.5.1', apply: true), 0);
      expect(workflowText(), contains('@v2.5.1'));
      expect(workflowText(), isNot(contains('@v2.5.0')));
    });

    test('a new minor or major needs a flag', () async {
      final runner = UpgradeRunner(root: dir.path);
      expect(await runner.run('2.6.0', apply: true), 1);
      expect(await runner.run('3.0.0', apply: true, allowMinor: true), 1);
      expect(workflowText(), contains('@v2.5.0'));
      expect(await runner.run('2.6.0', apply: true, allowMinor: true), 0);
      final yaml = File(p.join(dir.path, 'sweetmelon.yaml')).readAsStringSync();
      expect(yaml, contains('core: "2.6"'));
    });

    test('a dry run writes nothing and a loose version is refused', () async {
      expect(await UpgradeRunner(root: dir.path).run('2.5.1'), 0);
      expect(workflowText(), contains('@v2.5.0'));
      expect(await UpgradeRunner(root: dir.path).run('2.5'), 64);
    });
  });
}
