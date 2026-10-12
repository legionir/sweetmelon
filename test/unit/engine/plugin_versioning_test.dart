import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

void main() {
  group('SemanticVersion', () {
    test('parse simple version', () {
      final v = SemanticVersion.parse('1.2.3');
      expect(v.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
    });

    test('parse with pre-release', () {
      final v = SemanticVersion.parse('2.0.0-beta.1');
      expect(v.major, 2);
      expect(v.preRelease, 'beta.1');
      expect(v.isPreRelease, true);
    });

    test('parse with v prefix', () {
      final v = SemanticVersion.parse('v1.0.0');
      expect(v.major, 1);
    });

    test('comparison', () {
      final v1 = SemanticVersion.parse('1.0.0');
      final v2 = SemanticVersion.parse('1.1.0');
      final v3 = SemanticVersion.parse('2.0.0');

      expect(v1 < v2, true);
      expect(v2 < v3, true);
      expect(v3 > v1, true);
      expect(v1 == SemanticVersion.parse('1.0.0'), true);
    });

    test('isBreakingFrom', () {
      final v1 = SemanticVersion.parse('1.5.0');
      final v2 = SemanticVersion.parse('2.0.0');
      final v3 = SemanticVersion.parse('1.6.0');

      expect(v2.isBreakingFrom(v1), true);
      expect(v3.isBreakingFrom(v1), false);
    });
  });

  group('VersionConstraint', () {
    test('exact version', () {
      final c = ExactVersion(SemanticVersion.parse('1.0.0'));
      expect(c.allows(SemanticVersion.parse('1.0.0')), true);
      expect(c.allows(SemanticVersion.parse('1.0.1')), false);
    });

    test('min version', () {
      final c = MinVersion(SemanticVersion.parse('1.2.0'));
      expect(c.allows(SemanticVersion.parse('1.2.0')), true);
      expect(c.allows(SemanticVersion.parse('1.3.0')), true);
      expect(c.allows(SemanticVersion.parse('1.1.0')), false);
    });

    test('compatible with (caret)', () {
      final c = CompatibleWith(SemanticVersion.parse('1.2.0'));
      expect(c.allows(SemanticVersion.parse('1.2.0')), true);
      expect(c.allows(SemanticVersion.parse('1.9.0')), true);
      expect(c.allows(SemanticVersion.parse('2.0.0')), false);
      expect(c.allows(SemanticVersion.parse('1.1.0')), false);
    });

    test('parse constraint string', () {
      final c1 = parseConstraint('^1.0.0');
      expect(c1.allows(SemanticVersion.parse('1.5.0')), true);
      expect(c1.allows(SemanticVersion.parse('2.0.0')), false);

      final c2 = parseConstraint('>=2.0.0');
      expect(c2.allows(SemanticVersion.parse('2.0.0')), true);
      expect(c2.allows(SemanticVersion.parse('3.0.0')), true);

      final c3 = parseConstraint('*');
      expect(c3.allows(SemanticVersion.parse('999.0.0')), true);
    });
  });

  group('MigrationManager', () {
    late MigrationManager manager;

    setUp(() {
      manager = MigrationManager();
    });

    test('resolves method aliases', () {
      manager.registerMigration(
        'storage',
        MigrationStep(
          fromVersion: const SemanticVersion(major: 1, minor: 0, patch: 0),
          toVersion: const SemanticVersion(major: 2, minor: 0, patch: 0),
          description: 'v2 renames',
          migrate: (args) async => const MigrationResult.ok(),
          methodRenames: {'getValue': 'get', 'setValue': 'set'},
        ),
      );

      expect(manager.resolveMethod('storage', 'getValue'), 'get');
      expect(manager.resolveMethod('storage', 'setValue'), 'set');
      expect(manager.resolveMethod('storage', 'remove'), 'remove');
    });

    test('detects deprecated methods', () {
      manager.registerMigration(
        'http',
        MigrationStep(
          fromVersion: const SemanticVersion(major: 1, minor: 0, patch: 0),
          toVersion: const SemanticVersion(major: 2, minor: 0, patch: 0),
          description: 'v2 removes raw',
          migrate: (args) async => const MigrationResult.ok(),
          removedMethods: {'raw'},
        ),
      );

      expect(manager.isDeprecated('http', 'raw'), true);
      expect(manager.isDeprecated('http', 'get'), false);
    });

    test('transforms args between versions', () {
      manager.registerMigration(
        'http',
        MigrationStep(
          fromVersion: const SemanticVersion(major: 1, minor: 0, patch: 0),
          toVersion: const SemanticVersion(major: 1, minor: 1, patch: 0),
          description: 'rename timeout',
          migrate: (args) async => const MigrationResult.ok(),
          argTransforms: {
            'timeout': const ArgTransform.rename('timeoutMs'),
          },
        ),
      );

      final result = manager.transformArgs(
        'http',
        'get',
        {'url': 'https://test.com', 'timeout': 5000},
        SemanticVersion.parse('1.0.0'),
        SemanticVersion.parse('1.1.0'),
      );

      expect(result.containsKey('timeout'), false);
      expect(result['timeoutMs'], 5000);
      expect(result['url'], 'https://test.com');
    });

    test('getInfo returns migration details', () {
      manager.registerMigration(
        'test',
        MigrationStep(
          fromVersion: const SemanticVersion(major: 1, minor: 0, patch: 0),
          toVersion: const SemanticVersion(major: 2, minor: 0, patch: 0),
          description: 'test migration',
          migrate: (args) async => const MigrationResult.ok(),
          addedMethods: {'newMethod'},
          removedMethods: {'oldMethod'},
        ),
      );

      final info = manager.getInfo('test');
      expect(info['migrations'], hasLength(1));
      expect(info['deprecatedMethods'], contains('oldMethod'));
    });
  });
}
