import 'dart:async';

abstract class Plugin {
  String get name;
  String get version;
  String get description => '';
  List<String> get supportedMethods;
  List<String> get requiredPermissions => [];
  bool get cacheable => false;
  Duration get defaultCacheTtl => const Duration(minutes: 5);
  bool get isReady => _initialized;
  bool _initialized = false;

  Future<dynamic> onCall(String method, Map<String, dynamic> args);

  Future<void> initialize() async {
    if (_initialized) return; // جلوگیری از initialize دوباره
    await onInitialize();
    _initialized = true;
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    _initialized = false;
    await onDispose();
  }

  Future<void> onInitialize() async {}
  Future<void> onDispose() async {}
  Future<void> onPause() async {}
  Future<void> onResume() async {}
  bool supportsMethod(String method) => supportedMethods.contains(method);
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    return ValidationResult.valid();
  }

  @override
  String toString() => 'Plugin($name@$version)';
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warnings = const [],
  });

  factory ValidationResult.valid() => const ValidationResult(isValid: true);

  factory ValidationResult.invalid(String message) => ValidationResult(
        isValid: false,
        errorMessage: message,
      );

  factory ValidationResult.validWithWarnings(List<String> warnings) =>
      ValidationResult(
        isValid: true,
        warnings: warnings,
      );
}

class PluginManifest {
  final String name;
  final String version;
  final String description;
  final List<String> methods;
  final List<String> permissions;
  final Map<String, dynamic> config;
  final PluginCapabilities capabilities;

  const PluginManifest({
    required this.name,
    required this.version,
    required this.description,
    required this.methods,
    required this.permissions,
    required this.config,
    required this.capabilities,
  });

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
      name: json['name'] as String,
      version: json['version'] as String,
      description: json['description'] as String? ?? '',
      methods: List<String>.from(json['methods'] as List),
      permissions: List<String>.from(
        (json['permissions'] as List?) ?? [],
      ),
      config: (json['config'] as Map<String, dynamic>?) ?? {},
      capabilities: json['capabilities'] != null
          ? PluginCapabilities.fromJson(
              json['capabilities'] as Map<String, dynamic>,
            )
          : PluginCapabilities.defaults(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'description': description,
        'methods': methods,
        'permissions': permissions,
        'config': config,
        'capabilities': capabilities.toJson(),
      };
}

class PluginCapabilities {
  final bool supportsStreaming;
  final bool supportsBatch;
  final bool supportsCache;
  final int maxConcurrentCalls;

  const PluginCapabilities({
    required this.supportsStreaming,
    required this.supportsBatch,
    required this.supportsCache,
    required this.maxConcurrentCalls,
  });

  factory PluginCapabilities.defaults() => const PluginCapabilities(
        supportsStreaming: false,
        supportsBatch: true,
        supportsCache: false,
        maxConcurrentCalls: 10,
      );

  factory PluginCapabilities.fromJson(Map<String, dynamic> json) {
    return PluginCapabilities(
      supportsStreaming: json['supportsStreaming'] as bool? ?? false,
      supportsBatch: json['supportsBatch'] as bool? ?? true,
      supportsCache: json['supportsCache'] as bool? ?? false,
      maxConcurrentCalls: json['maxConcurrentCalls'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
        'supportsStreaming': supportsStreaming,
        'supportsBatch': supportsBatch,
        'supportsCache': supportsCache,
        'maxConcurrentCalls': maxConcurrentCalls,
      };
}
