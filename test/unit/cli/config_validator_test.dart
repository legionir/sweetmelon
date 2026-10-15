import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/cli/config_validator.dart';

import '../../helpers/core_minor.dart';

final _valid = '''
core: "$coreMinor"

project:
  name: demo_app
  version: 1.2.3+4
  display_name: "Demo App"
  application_id: com.acme.demo

plugins:
  storage:
    enabled: true
  camera:
    enabled: false
''';

void main() {
  const known = {'storage', 'camera', 'secure_storage'};

  List<ConfigIssue> run(String source) =>
      const ConfigValidator(knownPluginKeys: known).validate(source);

  group('valid file', () {
    test('has no issues', () {
      expect(run(_valid), isEmpty);
    });
  });

  group('project section', () {
    test('rejects a name with spaces or capitals', () {
      final issues = run(_valid.replaceFirst('demo_app', 'Demo App'));
      expect(issues, hasLength(1));
      expect(issues.single.isError, isTrue);
      expect(issues.single.message, contains('project.name'));
      expect(issues.single.line, 4);
    });

    test('rejects a version that is not semantic', () {
      final issues = run(_valid.replaceFirst('1.2.3+4', '1.2'));
      expect(issues.single.message, contains('project.version'));
    });

    test('requires display_name', () {
      final issues =
          run(_valid.replaceFirst('  display_name: "Demo App"\n', ''));
      expect(
        issues.any((i) => i.message.contains('display_name is required')),
        isTrue,
      );
    });

    test('rejects an application_id with one segment', () {
      final issues = run(_valid.replaceFirst('com.acme.demo', 'demo'));
      expect(issues.single.message, contains('application_id'));
    });

    test('warns about com.example application ids', () {
      final issues =
          run(_valid.replaceFirst('com.acme.demo', 'com.example.demo'));
      expect(issues.single.isError, isFalse);
      expect(issues.single.message, contains('com.example'));
    });

    test('warns about unknown keys but keeps going', () {
      final issues = run(_valid.replaceFirst(
          '  name: demo_app', '  name: demo_app\n  colour: red'));
      expect(issues.single.isError, isFalse);
      expect(issues.single.message, contains('colour'));
    });
  });

  group('plugins section', () {
    test('suggests the closest known plugin for a typo', () {
      final issues = run(_valid.replaceFirst('  camera:', '  cammera:'));
      expect(issues.single.isError, isTrue);
      expect(issues.single.message, contains('"cammera"'));
      expect(issues.single.message, contains('did you mean "camera"'));
    });

    test('reports a non-boolean enabled with its line', () {
      final issues =
          run(_valid.replaceFirst('enabled: true', 'enabled: "yes"'));
      expect(issues.single.isError, isTrue);
      expect(issues.single.message, contains('enabled must be true or false'));
      expect(issues.single.line, 11);
    });

    test('accepts a plugin with no settings (treated as enabled)', () {
      final issues = run('$_valid\n  secure_storage:\n');
      expect(issues, isEmpty);
    });

    test('skips the unknown-plugin check when no catalog is given', () {
      final issues = const ConfigValidator().validate(
        _valid.replaceFirst('  camera:', '  whatever:'),
      );
      expect(issues, isEmpty);
    });
  });

  group('structure', () {
    test('reports invalid YAML', () {
      final issues = run('project: [unclosed');
      expect(issues.single.isError, isTrue);
      expect(issues.single.message, contains('invalid YAML'));
    });

    test('reports a missing plugins section', () {
      final issues = run(
          'project:\n  name: demo_app\n  version: 1.0.0\n  display_name: X\n');
      expect(issues.any((i) => i.message.contains('"plugins"')), isTrue);
    });

    test('rejects a document that is not a mapping', () {
      final issues = run('- just\n- a list\n');
      expect(issues.single.message, contains('mapping'));
    });
  });
}
