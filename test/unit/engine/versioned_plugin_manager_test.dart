import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

/// Minimal host that mixes in VersioningSupport the way PluginManager does.
class VersionedHost with VersioningSupport {
  @override
  final MigrationManager migrationManager;

  VersionedHost(this.migrationManager);
}

MigrationStep renameStep() => MigrationStep(
      fromVersion: SemanticVersion.parse('1.0.0'),
      toVersion: SemanticVersion.parse('2.0.0'),
      description: 'rename fetch to load',
      migrate: (args) async => const MigrationResult.ok(),
      methodRenames: const {'fetch': 'load'},
      argTransforms: const {
        'oldName': ArgTransform.rename('newName'),
        'legacy': ArgTransform.remove(),
      },
    );

void main() {
  group('MigrationManager', () {
    test('resolveMethod returns the original name without aliases', () {
      final manager = MigrationManager();

      expect(manager.resolveMethod('store', 'get'), 'get');
    });

    test('resolveMethod maps renamed methods', () {
      final manager = MigrationManager()
        ..registerMigration('store', renameStep());

      expect(manager.resolveMethod('store', 'fetch'), 'load');
      expect(manager.resolveMethod('store', 'other'), 'other');
      expect(manager.resolveMethod('unrelated', 'fetch'), 'fetch');
    });

    test('transformArgs renames and removes args for crossed versions', () {
      final manager = MigrationManager()
        ..registerMigration('store', renameStep());

      final result = manager.transformArgs(
        'store',
        'load',
        {'oldName': 'a', 'legacy': true, 'keep': 1},
        SemanticVersion.parse('1.0.0'),
        SemanticVersion.parse('2.0.0'),
      );

      expect(result, {'newName': 'a', 'keep': 1});
    });

    test('transformArgs leaves args alone when no version boundary is crossed',
        () {
      final manager = MigrationManager()
        ..registerMigration('store', renameStep());

      final result = manager.transformArgs(
        'store',
        'load',
        {'oldName': 'a'},
        SemanticVersion.parse('2.0.0'),
        SemanticVersion.parse('2.0.0'),
      );

      expect(result, {'oldName': 'a'});
    });

    test('transformArgs returns args unchanged for unknown plugins', () {
      final manager = MigrationManager();
      final args = {'x': 1};

      final result = manager.transformArgs(
        'nope',
        'nope',
        args,
        SemanticVersion.parse('1.0.0'),
        SemanticVersion.parse('3.0.0'),
      );

      expect(result, args);
    });

    test('getInfo and allInfo expose registered migrations', () {
      final manager = MigrationManager()
        ..registerMigration('store', renameStep());

      expect(manager.getInfo('store'), isNotEmpty);
      expect(manager.allInfo, containsPair('store', anything));
    });
  });

  group('VersioningSupport.applyMigrations', () {
    test('returns the request untouched when nothing applies', () {
      final host = VersionedHost(MigrationManager());
      final request = PluginRequest.create(
        plugin: 'store',
        method: 'get',
        args: {'k': 'v'},
        version: '1.0.0',
      );

      final result = host.applyMigrations(request, '1.0.0');

      expect(identical(result, request), true);
    });

    test('rewrites method, args and version for migrated requests', () {
      final host = VersionedHost(
          MigrationManager()..registerMigration('store', renameStep()));
      final request = PluginRequest.create(
        plugin: 'store',
        method: 'fetch',
        args: {'oldName': 'a'},
        version: '1.0.0',
      );

      final result = host.applyMigrations(request, '2.0.0');

      expect(result.requestId, request.requestId);
      expect(result.plugin, 'store');
      expect(result.method, 'load');
      expect(result.version, '2.0.0');
      expect(result.args, {'newName': 'a'});
    });
  });
}
