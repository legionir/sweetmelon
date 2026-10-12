import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/cli/version_bump.dart';

void main() {
  group('bumpVersion', () {
    test('build keeps the name and increments the build number', () {
      final next = bumpVersion(name: '2.4.0', build: 7, kind: BumpKind.build);
      expect(next.full, '2.4.0+8');
    });

    test('patch increments patch and build', () {
      expect(
        bumpVersion(name: '2.4.9', build: 7, kind: BumpKind.patch).full,
        '2.4.10+8',
      );
    });

    test('minor resets patch and increments build', () {
      expect(
        bumpVersion(name: '2.4.9', build: 7, kind: BumpKind.minor).full,
        '2.5.0+8',
      );
    });

    test('major resets minor and patch and increments build', () {
      expect(
        bumpVersion(name: '2.4.9', build: 7, kind: BumpKind.major).full,
        '3.0.0+8',
      );
    });

    test('rejects a name that is not x.y.z', () {
      expect(
        () => bumpVersion(name: '2.4', build: 1, kind: BumpKind.patch),
        throwsFormatException,
      );
    });
  });

  group('pubspec helpers', () {
    test('reads name and build number', () {
      final v = readPubspecVersion('name: app\nversion: 1.2.3+45\n');
      expect(v?.name, '1.2.3');
      expect(v?.build, 45);
    });

    test('a missing build number reads as 0', () {
      expect(readPubspecVersion('version: 1.2.3\n')?.build, 0);
    });

    test('setPubspecVersion replaces only the version line', () {
      const before = 'name: app\nversion: 1.0.0+1\ndependencies:\n';
      final after = setPubspecVersion(before, const BuildVersion('2.0.0', 9));
      expect(after, 'name: app\nversion: 2.0.0+9\ndependencies:\n');
    });

    test('setProjectVersion changes only the project version', () {
      const yaml = 'project:\n  name: x\n  version: 1.0.0\nplugins:\n  a:\n';
      expect(
        setProjectVersion(yaml, '1.1.0'),
        'project:\n  name: x\n  version: 1.1.0\nplugins:\n  a:\n',
      );
    });
  });
}
