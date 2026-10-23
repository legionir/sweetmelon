import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/core_version.dart';
import 'package:yaml/yaml.dart';

/// The core version lives in several files. When they disagree a release is
/// refused late (the tag check) or a project is built against a core that says
/// another version ("this project needs core 2.5, but the core in use is 2.4.0").
/// These tests make the disagreement fail on the pull request instead.
///
/// To release 2.6.1: set it in `lib/core_version.dart`, `pubspec.yaml`
/// (`version: 2.6.1+1`) and `project.version` in `sweetmelon.yaml`, add a
/// `## [2.6.1]` section at the top of CHANGELOG.md, and for a new minor change
/// `core: "2.7"` in `sweetmelon.yaml` and the `@v2.x.y` pins in the docs.
void main() {
  final parts = sweetmelonCoreVersion.split('.');
  final minor = '${parts[0]}.${parts[1]}';

  test('lib/core_version.dart has the form the release workflow reads', () {
    // .github/workflows/release.yml extracts the version with sed from this line.
    final source = File('lib/core_version.dart').readAsStringSync();
    expect(
      RegExp(r"^const String sweetmelonCoreVersion = '\d+\.\d+\.\d+';$",
              multiLine: true)
          .hasMatch(source),
      isTrue,
    );
  });

  test('pubspec.yaml version is the core version', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    final name = pubspec['version'].toString().split('+').first;
    expect(name, sweetmelonCoreVersion);
  });

  test('sweetmelon.yaml project.version is the core version', () {
    final config = loadYaml(File('sweetmelon.yaml').readAsStringSync()) as Map;
    expect((config['project'] as Map)['version'].toString(),
        sweetmelonCoreVersion);
  });

  test('sweetmelon.yaml core: is the minor of the core version', () {
    final config = loadYaml(File('sweetmelon.yaml').readAsStringSync()) as Map;
    expect(config['core'].toString(), minor);
  });

  test('the newest CHANGELOG section is the core version', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    final first = RegExp(r'^## \[([^\]]+)\]', multiLine: true)
        .firstMatch(changelog)!
        .group(1);
    expect(first, sweetmelonCoreVersion);
  });

  test('documented pins are on the current minor', () {
    final pin = RegExp(r'(?:legionir/sweetmelon@|ref: )v(\d+\.\d+)\.\d+');
    final files = <File>[
      File('README.md'),
      File('action.yml'),
      ..._filesUnder('docs', '.md'),
      ..._filesUnder('examples', '.yml'),
    ];

    final stale = <String>[];
    for (final file in files) {
      for (final match in pin.allMatches(file.readAsStringSync())) {
        if (match.group(1) != minor) {
          stale.add('${file.path}: ${match.group(0)}');
        }
      }
    }
    expect(stale, isEmpty,
        reason: 'Update these pins to v$sweetmelonCoreVersion.');
  });
}

List<File> _filesUnder(String dir, String extension) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith(extension))
    .toList();
