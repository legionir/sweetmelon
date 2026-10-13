import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sweetmelon/cli/prepare_runner.dart';
import 'package:sweetmelon/cli/project_settings.dart';

const _yaml = '''
core: "2.4"

project:
  name: demo
  display_name: Demo
  version: 1.0.0

plugins:
  camera:
    enabled: true              # photo
  # a comment between
  nfc:
    enabled: false
''';

void main() {
  group('yaml edits', () {
    test('setProjectKey replaces an existing line', () {
      final out = setProjectKey('project:\n  icon: a.png\n', 'icon', 'b.png');
      expect(out, 'project:\n  icon: b.png\n');
    });

    test('setProjectKey adds the key after version', () {
      final out = setProjectKey(_yaml, 'dart_package', 'my_app');
      expect(out, contains('  version: 1.0.0\n  dart_package: my_app\n'));
    });

    test('setPluginEnabled flips only the named plugin', () {
      final out = setPluginEnabled(_yaml, 'nfc', true);
      expect(out, contains('nfc:\n    enabled: true'));
      expect(out, contains('camera:\n    enabled: true              # photo'));
      final off = setPluginEnabled(_yaml, 'camera', false);
      expect(off, contains('camera:\n    enabled: false              # photo'));
      expect(off, contains('nfc:\n    enabled: false'));
    });

    test('setPluginEnabled leaves an unlisted plugin alone by default', () {
      expect(setPluginEnabled(_yaml, 'nope', true), _yaml);
    });

    test('setPluginEnabled fills an empty plugins: {} mapping', () {
      final out = setPluginEnabled('core: "2.4"\nplugins: {}\n', 'camera', true,
          addIfMissing: true);
      expect(out, 'core: "2.4"\nplugins:\n  camera:\n    enabled: true\n');
    });

    test('setPluginEnabled can add an unlisted plugin', () {
      final out = setPluginEnabled(_yaml, 'nope', false, addIfMissing: true);
      expect(out, contains('plugins:\n  nope:\n    enabled: false\n  camera:'));
    });
  });

  group('PrepareRunner', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('prepare_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('refuses a core it was not built for', () async {
      File(p.join(dir.path, 'sweetmelon.yaml'))
          .writeAsStringSync(_yaml.replaceFirst('2.4', '9.9'));
      expect(
          await PrepareRunner(root: dir.path).run(const PrepareOverrides()), 1);
    });

    test('refuses a bad package name before writing anything', () async {
      final yaml = File(p.join(dir.path, 'sweetmelon.yaml'))
        ..writeAsStringSync(_yaml);
      final code = await PrepareRunner(root: dir.path)
          .run(const PrepareOverrides(applicationId: 'nodots'), apply: true);
      expect(code, 1);
      expect(yaml.readAsStringSync(), _yaml);
    });

    test('refuses a www folder without index.html', () async {
      File(p.join(dir.path, 'sweetmelon.yaml')).writeAsStringSync(_yaml);
      final code = await PrepareRunner(root: dir.path)
          .run(PrepareOverrides(www: dir.path));
      expect(code, 1);
    });

    test('a dry run writes nothing', () async {
      final yaml = File(p.join(dir.path, 'sweetmelon.yaml'))
        ..writeAsStringSync(_yaml);
      final code = await PrepareRunner(root: dir.path)
          .run(const PrepareOverrides(applicationId: 'com.acme.demo'));
      expect(code, 0);
      expect(yaml.readAsStringSync(), _yaml);
    });
  });
}
