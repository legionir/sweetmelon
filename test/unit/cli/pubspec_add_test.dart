import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/cli/pubspec_sync.dart';

const _pubspec = '''
name: demo
dependencies:
  flutter:
    sdk: flutter

  # Core
  path: ^1.9.0
  uuid: ^4.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^3.0.0

flutter:
  uses-material-design: true
''';

void main() {
  group('addMissingDependencies', () {
    test('adds missing packages sorted, below a comment, at the section end',
        () {
      final result = addMissingDependencies(
        _pubspec,
        wanted: {'sqflite': '^2.3.3+2', 'http': '^1.1.2'},
      );
      expect(result.added, ['http', 'sqflite']);
      expect(
        result.text,
        contains('  uuid: ^4.2.1\n'
            '\n'
            '  # Added by `sweetmelon sync` for enabled plugins\n'
            '  http: ^1.1.2\n'
            '  sqflite: ^2.3.3+2\n'
            '\n'
            'dev_dependencies:'),
      );
    });

    test('keeps everything outside dependencies untouched', () {
      final result =
          addMissingDependencies(_pubspec, wanted: {'http': '^1.1.2'});
      expect(result.text.split('dev_dependencies:').last,
          _pubspec.split('dev_dependencies:').last);
    });

    test('does not touch packages that are already declared', () {
      final result = addMissingDependencies(
        _pubspec,
        wanted: {'path': '^2.0.0', 'uuid': '^9.0.0', 'lints': '^1.0.0'},
      );
      expect(result.added, isEmpty);
      expect(result.text, _pubspec);
    });

    test('is idempotent', () {
      final once = addMissingDependencies(_pubspec, wanted: {'http': '^1.1.2'});
      final twice =
          addMissingDependencies(once.text, wanted: {'http': '^1.1.2'});
      expect(twice.added, isEmpty);
      expect(twice.text, once.text);
    });

    test('works when dependencies is the last section', () {
      const text = 'name: demo\ndependencies:\n  path: ^1.9.0\n';
      final result = addMissingDependencies(text, wanted: {'http': '^1.1.2'});
      expect(result.text,
          startsWith('name: demo\ndependencies:\n  path: ^1.9.0\n'));
      expect(result.text, contains('  http: ^1.1.2'));
      expect(result.text, endsWith('\n'));
    });

    test('returns the text unchanged without a dependencies section', () {
      const text = 'name: demo\n';
      final result = addMissingDependencies(text, wanted: {'http': '^1'});
      expect(result.added, isEmpty);
      expect(result.text, text);
    });
  });
}
