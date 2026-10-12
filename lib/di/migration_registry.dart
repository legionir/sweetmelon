import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

/// ثبت همه migration‌ها در اینجا
class MigrationRegistry {
  static void registerAll(MigrationManager manager) {
    _registerStorageMigrations(manager);
    _registerHttpMigrations(manager);
    _registerDatabaseMigrations(manager);
  }

  /// مثال: Storage plugin از v1 به v2 تغییر کرده
  static void _registerStorageMigrations(MigrationManager manager) {
    manager.registerMigrations('storage', [
      MigrationStep(
        fromVersion: const SemanticVersion(major: 1, minor: 0, patch: 0),
        toVersion: const SemanticVersion(major: 2, minor: 0, patch: 0),
        description: 'Storage v2: renamed getValue to get, setValue to set',
        migrate: (args) async => const MigrationResult.ok(),
        methodRenames: {
          'getValue': 'get',
          'setValue': 'set',
          'removeValue': 'remove',
          'getAllKeys': 'keys',
          'hasValue': 'has',
        },
        removedMethods: {'getAll'},
        addedMethods: {'getInfo'},
      ),
    ]);
  }

  /// مثال: HTTP plugin args تغییر کرده
  static void _registerHttpMigrations(MigrationManager manager) {
    manager.registerMigrations('http', [
      MigrationStep(
        fromVersion: const SemanticVersion(major: 1, minor: 0, patch: 0),
        toVersion: const SemanticVersion(major: 1, minor: 1, patch: 0),
        description: 'HTTP v1.1: renamed timeout to timeoutMs',
        migrate: (args) async => const MigrationResult.ok(),
        argTransforms: {
          'timeout': const ArgTransform.rename('timeoutMs'),
        },
      ),
      MigrationStep(
        fromVersion: const SemanticVersion(major: 1, minor: 1, patch: 0),
        toVersion: const SemanticVersion(major: 2, minor: 0, patch: 0),
        description: 'HTTP v2: removed raw method, added bodyType auto',
        migrate: (args) async => const MigrationResult.ok(),
        removedMethods: {'raw'},
        argTransforms: {
          'contentType': ArgTransform(
            renamedTo: 'bodyType',
            transformer: (value) {
              if (value == 'application/json') return 'json';
              if (value == 'application/x-www-form-urlencoded') return 'form';
              return 'auto';
            },
          ),
        },
      ),
    ]);
  }

  /// Database plugin migration
  static void _registerDatabaseMigrations(MigrationManager manager) {
    manager.registerMigrations('database', [
      MigrationStep(
        fromVersion: const SemanticVersion(major: 1, minor: 0, patch: 0),
        toVersion: const SemanticVersion(major: 1, minor: 1, patch: 0),
        description:
            'Database v1.1: added batch support, renamed exec to execute',
        migrate: (args) async => const MigrationResult.ok(),
        methodRenames: {
          'exec': 'execute',
          'sql': 'rawQuery',
        },
        addedMethods: {'batch', 'tableExists'},
      ),
    ]);
  }
}
