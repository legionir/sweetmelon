import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/cli/package_rename.dart';

const _old = 'com.core.sweetmelon';
const _new = 'com.acme.app';

// Built from two literals so that `rename --dart-package` does not rewrite the
// fixtures of this very test when someone renames the package of a project
// that contains the framework tests.
const _oldPkg = 'package:' 'sweetmelon' '/';

void main() {
  group('validateApplicationId', () {
    test('accepts a normal id', () {
      expect(validateApplicationId(_new), isNull);
    });

    test('rejects one segment, uppercase and digit-first segments', () {
      expect(validateApplicationId('app'), isNotNull);
      expect(validateApplicationId('com.Acme.app'), isNotNull);
      expect(validateApplicationId('com.1acme.app'), isNotNull);
    });

    test('rejects reserved words as segments', () {
      expect(validateApplicationId('com.acme.class'), isNotNull);
    });
  });

  test('readGradleApplicationId reads the value', () {
    expect(
      readGradleApplicationId('defaultConfig {\n  applicationId = "$_old"\n}'),
      _old,
    );
  });

  group('renameIdentifierInText', () {
    test('replaces the whole id and fully qualified class names', () {
      expect(
        renameIdentifierInText(
          'package $_old\nimport $_old.MainActivity\n',
          _old,
          _new,
        ),
        'package $_new\nimport $_new.MainActivity\n',
      );
    });

    test('does not touch longer identifiers', () {
      const text = 'x.$_old.y ${_old}X ${_old}_y ${_old}Z';
      expect(renameIdentifierInText(text, _old, _new), text);
    });
  });

  test('moves the Kotlin file and rewrites its package line', () {
    final plan = planPackageRename(
      oldId: _old,
      newId: _new,
      texts: {
        'android/app/src/main/kotlin/com/core/sweetmelon/MainActivity.kt':
            'package com.core.sweetmelon\n\nclass MainActivity\n',
        'android/app/build.gradle.kts': 'applicationId = "$_old"\n',
        'ios/Runner.xcodeproj/project.pbxproj':
            'PRODUCT_BUNDLE_IDENTIFIER = $_old;\n',
        'lib/main.dart': 'package:sweetmelon/main.dart',
      },
    );

    final moved = plan.files.singleWhere((f) => f.isMove);
    expect(moved.oldPath,
        'android/app/src/main/kotlin/com/core/sweetmelon/MainActivity.kt');
    expect(moved.newPath,
        'android/app/src/main/kotlin/com/acme/app/MainActivity.kt');
    expect(moved.content, 'package $_new\n\nclass MainActivity\n');

    final gradle = plan.files
        .singleWhere((f) => f.newPath == 'android/app/build.gradle.kts');
    expect(gradle.content, 'applicationId = "$_new"\n');

    expect(plan.files.any((f) => f.newPath == 'lib/main.dart'), isFalse,
        reason: 'Dart files are not renamed');
  });

  test('a Kotlin file whose package differs stays in place with a warning', () {
    final plan = planPackageRename(
      oldId: _old,
      newId: _new,
      texts: {
        'android/app/src/main/kotlin/com/core/sweetmelon/Other.kt':
            'package com.other\n',
      },
    );
    expect(plan.files, isEmpty);
    expect(plan.warnings, hasLength(1));
  });

  test('refuses an invalid target id', () {
    expect(
      () => planPackageRename(oldId: _old, newId: 'Bad.Id', texts: {}),
      throwsFormatException,
    );
  });

  group('Dart package rename', () {
    test('validateDartPackageName', () {
      expect(validateDartPackageName('my_app'), isNull);
      expect(validateDartPackageName('MyApp'), isNotNull);
      expect(validateDartPackageName('1app'), isNotNull);
      expect(validateDartPackageName('my-app'), isNotNull);
      expect(validateDartPackageName('class'), isNotNull);
      expect(validateDartPackageName('flutter'), isNotNull);
      expect(validateDartPackageName('path', declared: {'path'}), isNotNull);
    });

    test('readPubspecName reads only the top-level name', () {
      expect(readPubspecName('name: demo\nflutter:\n  name: other\n'), 'demo');
      expect(readPubspecName('flutter:\n  name: other\n'), isNull);
    });

    final texts = <String, String>{
      'pubspec.yaml': 'name: sweetmelon\ndependencies:\n  path: ^1.9.0\n',
      'lib/main.dart': "import '${_oldPkg}app.dart';\n"
          "import 'package:path/path.dart';\n",
      'lib/plugins/x/pubspec.yaml':
          'name: x\ndependencies:\n  sweetmelon:\n    path: ../../..\n',
      'lib/plugins/x/lib/x.dart': "import '${_oldPkg}plugins/y.dart';\n",
      'test/a_test.dart': "import '${_oldPkg}a.dart';\n",
      'tool/plugin_catalog.json': '{"import": "${_oldPkg}plugins/x"}',
      'docs/guide.md': '$_oldPkg in docs is left alone',
      'android/app/build.gradle.kts': '$_oldPkg outside the roots',
    };

    test('renames name, nested dependency key and package imports', () {
      final plan = planDartPackageRename(
          oldName: 'sweetmelon', newName: 'my_app', texts: texts);
      expect(plan.files['pubspec.yaml'], startsWith('name: my_app\n'));
      expect(plan.files['lib/main.dart'],
          "import 'package:my_app/app.dart';\nimport 'package:path/path.dart';\n");
      expect(plan.files['lib/plugins/x/pubspec.yaml'],
          contains('  my_app:\n    path: ../../..'));
      expect(plan.files['lib/plugins/x/lib/x.dart'],
          "import 'package:my_app/plugins/y.dart';\n");
      expect(plan.files['test/a_test.dart'], contains('package:my_app/a.dart'));
      expect(plan.files['tool/plugin_catalog.json'],
          contains('package:my_app/plugins/x'));
    });

    test('leaves files outside the renamed roots alone', () {
      final plan = planDartPackageRename(
          oldName: 'sweetmelon', newName: 'my_app', texts: texts);
      expect(plan.files.keys, isNot(contains('docs/guide.md')));
      expect(plan.files.keys, isNot(contains('android/app/build.gradle.kts')));
    });

    test('does not mistake a longer package name for the old one', () {
      final plan = planDartPackageRename(
        oldName: 'sweetmelon',
        newName: 'my_app',
        texts: {
          'pubspec.yaml': 'name: sweetmelon\n',
          'lib/a.dart': "import 'package:sweetmelon_extra/a.dart';\n",
        },
      );
      expect(plan.files.keys, ['pubspec.yaml']);
    });

    test('rejects a name used by a dependency and an unchanged name', () {
      expect(
        () => planDartPackageRename(
            oldName: 'sweetmelon', newName: 'path', texts: texts),
        throwsFormatException,
      );
      expect(
        () => planDartPackageRename(
            oldName: 'sweetmelon', newName: 'sweetmelon', texts: texts),
        throwsFormatException,
      );
    });
  });
}
