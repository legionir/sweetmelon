import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/cli/icon_generator.dart';
import 'package:sweetmelon/cli/project_doctor.dart';

const _yaml = '''
project:
  name: app
  version: 1.0.0
  display_name: App
  application_id: com.acme.app
plugins:
  camera:
    enabled: true
''';

Set<String> _allIconPaths() => {
      for (final t in iconTargets()) t.path,
      '$iosAppIconDir/Contents.json',
      'android/key.properties',
    };

ProjectSnapshot _healthy({Set<String>? paths}) => ProjectSnapshot(
      paths: paths ?? _allIconPaths(),
      yaml: _yaml,
      pubspec: 'name: app\nversion: 1.0.0+3\n',
      gradle: 'applicationId = "com.acme.app"\n',
      catalogKeys: const {'camera'},
    );

DoctorLevel? _levelOf(List<DoctorFinding> findings, String area) {
  for (final f in findings) {
    if (f.area == area && f.level != DoctorLevel.ok) return f.level;
  }
  return null;
}

void main() {
  test('a healthy project has no failures', () {
    final findings = checkProject(_healthy());
    expect(findings.where((f) => f.level == DoctorLevel.fail), isEmpty);
  });

  test('template application id is a failure', () {
    final findings = checkProject(ProjectSnapshot(
      paths: _allIconPaths(),
      yaml: _yaml,
      pubspec: 'version: 1.0.0+3\n',
      gradle: 'applicationId = "com.example.app"\n',
      catalogKeys: const {'camera'},
    ));
    expect(_levelOf(findings, 'application id'), DoctorLevel.fail);
  });

  test('yaml and gradle application ids must match', () {
    final findings = checkProject(ProjectSnapshot(
      paths: _allIconPaths(),
      yaml: _yaml,
      pubspec: 'version: 1.0.0+3\n',
      gradle: 'applicationId = "com.other.app"\n',
      catalogKeys: const {'camera'},
    ));
    expect(_levelOf(findings, 'application id'), DoctorLevel.fail);
  });

  test('pubspec version must match project.version', () {
    final findings = checkProject(ProjectSnapshot(
      paths: _allIconPaths(),
      yaml: _yaml,
      pubspec: 'version: 0.9.0+3\n',
      gradle: 'applicationId = "com.acme.app"\n',
      catalogKeys: const {'camera'},
    ));
    expect(_levelOf(findings, 'version'), DoctorLevel.fail);
  });

  test('missing mipmap icons fail the Android icon check', () {
    final paths = _allIconPaths()
      ..removeWhere((p) => p.contains('mipmap-xhdpi'));
    final findings = checkProject(_healthy(paths: paths));
    expect(_levelOf(findings, 'Android icons'), DoctorLevel.fail);
  });

  test('missing iOS Contents.json fails the iOS icon check', () {
    final paths = _allIconPaths()..remove('$iosAppIconDir/Contents.json');
    final findings = checkProject(_healthy(paths: paths));
    expect(_levelOf(findings, 'iOS icons'), DoctorLevel.fail);
  });

  test('pending sync is a failure, and imported-while-disabled a warning', () {
    final findings = checkProject(ProjectSnapshot(
      paths: _allIconPaths(),
      yaml: _yaml,
      pubspec: 'version: 1.0.0+3\n',
      gradle: 'applicationId = "com.acme.app"\n',
      catalogKeys: const {'camera'},
      syncWarnings: const ['"x" is off but still imported'],
      pendingSync: const ['ios/Runner/Info.plist is out of date'],
    ));
    expect(_levelOf(findings, 'sync'), DoctorLevel.fail);
    expect(_levelOf(findings, 'plugins'), DoctorLevel.warn);
  });

  test('missing yaml is a failure', () {
    final findings = checkProject(const ProjectSnapshot(paths: {}));
    expect(_levelOf(findings, 'sweetmelon.yaml'), DoctorLevel.fail);
  });

  test('missing catalog is a warning', () {
    final findings = checkProject(const ProjectSnapshot(
      paths: {},
      yaml: _yaml,
    ));
    expect(_levelOf(findings, 'plugin catalog'), DoctorLevel.warn);
  });

  group('plugin drift', () {
    ProjectSnapshot withPlugins(String yaml, Set<String> catalog,
            {Set<String>? dirs}) =>
        ProjectSnapshot(
          paths: _allIconPaths(),
          yaml: yaml,
          pubspec: 'version: 1.0.0+3\n',
          gradle: 'applicationId = "com.acme.app"\n',
          catalogKeys: catalog,
          registeredPluginKeys: catalog,
          pluginDirs: dirs,
        );

    const yamlOff = '''
project:
  name: app
  version: 1.0.0
  display_name: App
  application_id: com.acme.app
plugins:
  camera:
    enabled: false
''';

    test('registered but disabled in yaml is a failure', () {
      final findings = checkProject(withPlugins(yamlOff, {'camera'}));
      expect(
        findings.any((f) =>
            f.level == DoctorLevel.fail && f.message.contains('"camera"')),
        isTrue,
      );
    });

    test('enabled in yaml but not registered is a failure', () {
      final findings = checkProject(withPlugins(_yaml, const {}));
      expect(
        findings.any((f) =>
            f.level == DoctorLevel.fail && f.message.contains('"camera"')),
        isTrue,
      );
    });

    test('a plugin folder missing from yaml is a warning', () {
      final findings = checkProject(
          withPlugins(_yaml, const {'camera'}, dirs: {'camera', 'nfc'}));
      expect(
        findings.any((f) =>
            f.level == DoctorLevel.warn &&
            f.message.contains('lib/plugins/nfc')),
        isTrue,
      );
    });

    test('enabledFlags reads missing flags as true', () {
      expect(enabledFlags('plugins:\n  a:\n  b:\n    enabled: false\n'),
          {'a': true, 'b': false});
    });
  });
}
