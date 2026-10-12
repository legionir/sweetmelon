import 'dart:async';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'plugin_versioning.dart';

/// یک migration step
class MigrationStep {
  final SemanticVersion fromVersion;
  final SemanticVersion toVersion;
  final String description;
  final Future<MigrationResult> Function(Map<String, dynamic> args) migrate;
  final Map<String, ArgTransform>? argTransforms;
  final Map<String, String>? methodRenames;
  final Set<String>? removedMethods;
  final Set<String>? addedMethods;

  const MigrationStep({
    required this.fromVersion,
    required this.toVersion,
    required this.description,
    required this.migrate,
    this.argTransforms,
    this.methodRenames,
    this.removedMethods,
    this.addedMethods,
  });
}

/// تبدیل args
class ArgTransform {
  final String? renamedTo;
  final dynamic Function(dynamic oldValue)? transformer;
  final bool removed;
  final dynamic defaultValue;

  const ArgTransform({
    this.renamedTo,
    this.transformer,
    this.removed = false,
    this.defaultValue,
  });

  const ArgTransform.rename(String newName)
      : renamedTo = newName,
        transformer = null,
        removed = false,
        defaultValue = null;

  const ArgTransform.remove()
      : renamedTo = null,
        transformer = null,
        removed = true,
        defaultValue = null;
}

class MigrationResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? transformedArgs;

  const MigrationResult({
    required this.success,
    this.message,
    this.transformedArgs,
  });

  const MigrationResult.ok([this.message])
      : success = true,
        transformedArgs = null;

  const MigrationResult.failed(this.message)
      : success = false,
        transformedArgs = null;
}

/// Migration Manager — مدیریت migration بین نسخه‌ها
class MigrationManager {
  final Map<String, List<MigrationStep>> _migrations = {};
  final Map<String, Map<String, String>> _methodAliases = {};
  final Map<String, Set<String>> _deprecatedMethods = {};

  /// ثبت migration برای یک پلاگین
  void registerMigration(String pluginName, MigrationStep step) {
    _migrations.putIfAbsent(pluginName, () => []);
    _migrations[pluginName]!.add(step);

    // Sort by version
    _migrations[pluginName]!
        .sort((a, b) => a.fromVersion.compareTo(b.fromVersion));

    BridgeLogger.debug(
      'Migration',
      'Registered migration for $pluginName: '
          '${step.fromVersion} → ${step.toVersion}',
    );

    // ثبت method renames
    if (step.methodRenames != null) {
      _methodAliases.putIfAbsent(pluginName, () => {});
      _methodAliases[pluginName]!.addAll(step.methodRenames!);
    }

    // ثبت removed methods
    if (step.removedMethods != null) {
      _deprecatedMethods.putIfAbsent(pluginName, () => {});
      _deprecatedMethods[pluginName]!.addAll(step.removedMethods!);
    }
  }

  /// ثبت چندین migration
  void registerMigrations(
    String pluginName,
    List<MigrationStep> steps,
  ) {
    for (final step in steps) {
      registerMigration(pluginName, step);
    }
  }

  /// resolve اسم method (با در نظر گرفتن renames)
  String resolveMethod(String pluginName, String method) {
    final aliases = _methodAliases[pluginName];
    if (aliases == null) return method;

    final resolved = aliases[method];
    if (resolved != null) {
      BridgeLogger.debug(
        'Migration',
        '[$pluginName] Method aliased: $method → $resolved',
      );
      return resolved;
    }

    return method;
  }

  /// آیا method deprecated هست؟
  bool isDeprecated(String pluginName, String method) {
    return _deprecatedMethods[pluginName]?.contains(method) ?? false;
  }

  /// تبدیل args بر اساس migration
  Map<String, dynamic> transformArgs(
    String pluginName,
    String method,
    Map<String, dynamic> args,
    SemanticVersion requestedVersion,
    SemanticVersion currentVersion,
  ) {
    final migrations = _migrations[pluginName];
    if (migrations == null || migrations.isEmpty) return args;

    var transformedArgs = Map<String, dynamic>.from(args);

    for (final migration in migrations) {
      if (requestedVersion < migration.toVersion &&
          currentVersion >= migration.toVersion) {
        // این migration باید اعمال بشه

        if (migration.argTransforms != null) {
          final methodTransforms = migration.argTransforms!;

          for (final entry in methodTransforms.entries) {
            final argName = entry.key;
            final transform = entry.value;

            if (transform.removed) {
              transformedArgs.remove(argName);
              continue;
            }

            if (transform.renamedTo != null &&
                transformedArgs.containsKey(argName)) {
              transformedArgs[transform.renamedTo!] =
                  transformedArgs.remove(argName);
            }

            if (transform.transformer != null &&
                transformedArgs.containsKey(
                  transform.renamedTo ?? argName,
                )) {
              final key = transform.renamedTo ?? argName;
              transformedArgs[key] = transform.transformer!(
                transformedArgs[key],
              );
            }

            if (transform.defaultValue != null &&
                !transformedArgs.containsKey(
                  transform.renamedTo ?? argName,
                )) {
              transformedArgs[transform.renamedTo ?? argName] =
                  transform.defaultValue;
            }
          }
        }
      }
    }

    return transformedArgs;
  }

  /// گرفتن لیست migration‌ها بین دو نسخه
  List<MigrationStep> getMigrationPath(
    String pluginName,
    SemanticVersion from,
    SemanticVersion to,
  ) {
    final migrations = _migrations[pluginName];
    if (migrations == null) return [];

    return migrations.where((m) {
      return m.fromVersion >= from && m.toVersion <= to;
    }).toList();
  }

  /// اطلاعات migration برای یک پلاگین
  Map<String, dynamic> getInfo(String pluginName) {
    final migrations = _migrations[pluginName] ?? [];
    final aliases = _methodAliases[pluginName] ?? {};
    final deprecated = _deprecatedMethods[pluginName] ?? {};

    return {
      'plugin': pluginName,
      'migrations': migrations
          .map((m) => {
                'from': m.fromVersion.toString(),
                'to': m.toVersion.toString(),
                'description': m.description,
                'methodRenames': m.methodRenames,
                'removedMethods': m.removedMethods?.toList(),
                'addedMethods': m.addedMethods?.toList(),
              })
          .toList(),
      'activeAliases': aliases,
      'deprecatedMethods': deprecated.toList(),
    };
  }

  /// همه اطلاعات migration
  Map<String, dynamic> get allInfo {
    return _migrations.map(
      (key, _) => MapEntry(key, getInfo(key)),
    );
  }
}

/// Deprecation warning wrapper
class DeprecationNotice {
  final String plugin;
  final String method;
  final String? replacement;
  final String? message;
  final SemanticVersion? removedIn;

  const DeprecationNotice({
    required this.plugin,
    required this.method,
    this.replacement,
    this.message,
    this.removedIn,
  });

  String get warning {
    final buf = StringBuffer();
    buf.write('DEPRECATED: $plugin.$method');
    if (replacement != null) buf.write(' → use $replacement instead');
    if (removedIn != null) buf.write(' (will be removed in $removedIn)');
    if (message != null) buf.write(' — $message');
    return buf.toString();
  }

  Map<String, dynamic> toJson() => {
        'plugin': plugin,
        'method': method,
        'replacement': replacement,
        'message': message,
        'removedIn': removedIn?.toString(),
      };
}
