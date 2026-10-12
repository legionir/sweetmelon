import 'package:sweetmelon/packages/core/lib/core.dart';
import 'plugin_versioning.dart';
import 'plugin_migration.dart';

/// Mixin for PluginManager to add versioning support
mixin VersioningSupport {
  MigrationManager get migrationManager;

  /// بررسی و اعمال migration قبل از اجرای درخواست
  PluginRequest applyMigrations(
    PluginRequest request,
    String currentPluginVersion,
  ) {
    final pluginName = request.plugin;
    final requestedVersion = SemanticVersion.parse(request.version);
    final currentVersion = SemanticVersion.parse(currentPluginVersion);

    // بررسی deprecation
    if (migrationManager.isDeprecated(pluginName, request.method)) {
      BridgeLogger.warn(
        'Versioning',
        'Method ${request.plugin}.${request.method} is deprecated',
      );
    }

    // resolve method name
    final resolvedMethod = migrationManager.resolveMethod(
      pluginName,
      request.method,
    );

    // transform args
    final transformedArgs = migrationManager.transformArgs(
      pluginName,
      resolvedMethod,
      request.args,
      requestedVersion,
      currentVersion,
    );

    if (resolvedMethod != request.method || transformedArgs != request.args) {
      BridgeLogger.info(
        'Versioning',
        'Migrated ${request.plugin}: '
            '${request.method} → $resolvedMethod '
            '(v${request.version} → v$currentPluginVersion)',
      );

      return PluginRequest(
        requestId: request.requestId,
        timestamp: request.timestamp,
        plugin: request.plugin,
        version: currentPluginVersion,
        method: resolvedMethod,
        args: transformedArgs,
        metadata: request.metadata,
      );
    }

    return request;
  }
}
