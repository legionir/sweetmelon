import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/cli/package_rename.dart';

const _old = 'com.core.sweetmelon';
const _new = 'com.acme.app';

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
}
