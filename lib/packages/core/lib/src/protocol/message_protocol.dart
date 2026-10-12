import 'dart:convert';

import 'package:uuid/uuid.dart';

abstract class BaseMessage {
  final String requestId;
  final DateTime timestamp;

  const BaseMessage({
    required this.requestId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson();
}

class PluginRequest extends BaseMessage {
  final String plugin;
  final String version;
  final String method;
  final Map<String, dynamic> args;
  final RequestMetadata metadata;

  const PluginRequest({
    required super.requestId,
    required super.timestamp,
    required this.plugin,
    required this.version,
    required this.method,
    required this.args,
    required this.metadata,
  });

  factory PluginRequest.create({
    required String plugin,
    required String method,
    Map<String, dynamic>? args,
    String version = '1.0.0',
  }) {
    return PluginRequest(
      requestId: const Uuid().v4(),
      timestamp: DateTime.now(),
      plugin: plugin,
      version: version,
      method: method,
      args: args ?? {},
      metadata: RequestMetadata.defaults(),
    );
  }

  factory PluginRequest.fromJson(Map<String, dynamic> json) {
    return PluginRequest(
      requestId: json['requestId'] as String? ?? const Uuid().v4(),
      timestamp: DateTime.tryParse(
            json['timestamp'] as String? ?? '',
          ) ??
          DateTime.now(),
      plugin: json['plugin'] as String,
      version: json['version'] as String? ?? '1.0.0',
      method: json['method'] as String,
      args: json['args'] == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(json['args'] as Map),
      metadata: json['metadata'] != null
          ? RequestMetadata.fromJson(
              Map<String, dynamic>.from(json['metadata'] as Map),
            )
          : RequestMetadata.defaults(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'timestamp': timestamp.toIso8601String(),
        'plugin': plugin,
        'version': version,
        'method': method,
        'args': args,
        'metadata': metadata.toJson(),
      };

  @override
  String toString() => jsonEncode(toJson());
}

class PluginResponse extends BaseMessage {
  final bool success;
  final dynamic data;
  final PluginError? error;
  final ResponseMetadata metadata;

  const PluginResponse({
    required super.requestId,
    required super.timestamp,
    required this.success,
    this.data,
    this.error,
    required this.metadata,
  });

  factory PluginResponse.success({
    required String requestId,
    required dynamic data,
    ResponseMetadata? metadata,
  }) {
    return PluginResponse(
      requestId: requestId,
      timestamp: DateTime.now(),
      success: true,
      data: data,
      metadata: metadata ?? ResponseMetadata.defaults(),
    );
  }

  factory PluginResponse.failure({
    required String requestId,
    required PluginError error,
    ResponseMetadata? metadata,
  }) {
    return PluginResponse(
      requestId: requestId,
      timestamp: DateTime.now(),
      success: false,
      error: error,
      metadata: metadata ?? ResponseMetadata.defaults(),
    );
  }

  factory PluginResponse.fromJson(Map<String, dynamic> json) {
    return PluginResponse(
      requestId: json['requestId'] as String,
      timestamp: DateTime.tryParse(
            json['timestamp'] as String? ?? '',
          ) ??
          DateTime.now(),
      success: json['success'] as bool? ?? false,
      data: json['data'],
      error: json['error'] != null
          ? PluginError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] != null
          ? ResponseMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            )
          : ResponseMetadata.defaults(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'timestamp': timestamp.toIso8601String(),
        'success': success,
        if (data != null) 'data': data,
        if (error != null) 'error': error!.toJson(),
        'metadata': metadata.toJson(),
      };
}

enum PluginErrorCode {
  permissionDenied('PERMISSION_DENIED'),
  pluginNotFound('PLUGIN_NOT_FOUND'),
  methodNotFound('METHOD_NOT_FOUND'),
  invalidArgs('INVALID_ARGS'),
  timeout('TIMEOUT'),
  rateLimitExceeded('RATE_LIMIT_EXCEEDED'),
  executionError('EXECUTION_ERROR'),
  sandboxViolation('SANDBOX_VIOLATION'),
  networkError('NETWORK_ERROR'),
  unknown('UNKNOWN');

  final String code;
  const PluginErrorCode(this.code);

  static PluginErrorCode fromString(String code) {
    return PluginErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => PluginErrorCode.unknown,
    );
  }
}

class PluginError {
  final PluginErrorCode code;
  final String message;
  final Map<String, dynamic>? details;
  final String? stackTrace;

  const PluginError({
    required this.code,
    required this.message,
    this.details,
    this.stackTrace,
  });

  factory PluginError.fromJson(Map<String, dynamic> json) {
    return PluginError(
      code: PluginErrorCode.fromString(json['code'] as String? ?? 'UNKNOWN'),
      message: json['message'] as String? ?? 'Unknown error',
      details: json['details'] as Map<String, dynamic>?,
      stackTrace: json['stackTrace'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code.code,
        'message': message,
        if (details != null) 'details': details,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };
}

class RequestMetadata {
  final String? sessionId;
  final String? userId;
  final Map<String, String> headers;

  const RequestMetadata({
    this.sessionId,
    this.userId,
    required this.headers,
  });

  factory RequestMetadata.defaults() => const RequestMetadata(headers: {});

  factory RequestMetadata.fromJson(Map<String, dynamic> json) {
    return RequestMetadata(
      sessionId: json['sessionId'] as String?,
      userId: json['userId'] as String?,
      headers: Map<String, String>.from(
        (json['headers'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        if (sessionId != null) 'sessionId': sessionId,
        if (userId != null) 'userId': userId,
        'headers': headers,
      };
}

class ResponseMetadata {
  final int processingTimeMs;
  final String? pluginVersion;
  final bool fromCache;

  const ResponseMetadata({
    required this.processingTimeMs,
    this.pluginVersion,
    required this.fromCache,
  });

  factory ResponseMetadata.defaults() => const ResponseMetadata(
        processingTimeMs: 0,
        fromCache: false,
      );

  factory ResponseMetadata.fromJson(Map<String, dynamic> json) {
    return ResponseMetadata(
      processingTimeMs: json['processingTimeMs'] as int? ?? 0,
      pluginVersion: json['pluginVersion'] as String?,
      fromCache: json['fromCache'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'processingTimeMs': processingTimeMs,
        if (pluginVersion != null) 'pluginVersion': pluginVersion,
        'fromCache': fromCache,
      };
}

class BatchRequest {
  final String batchId;
  final List<PluginRequest> requests;
  final BatchOptions options;

  const BatchRequest({
    required this.batchId,
    required this.requests,
    required this.options,
  });

  factory BatchRequest.create(List<PluginRequest> requests) {
    return BatchRequest(
      batchId: const Uuid().v4(),
      requests: requests,
      options: BatchOptions.defaults(),
    );
  }

  Map<String, dynamic> toJson() => {
        'batchId': batchId,
        'requests': requests.map((r) => r.toJson()).toList(),
        'options': options.toJson(),
      };
}

class BatchOptions {
  final bool parallel;
  final bool stopOnError;
  final int? timeoutMs;

  const BatchOptions({
    required this.parallel,
    required this.stopOnError,
    this.timeoutMs,
  });

  factory BatchOptions.defaults() => const BatchOptions(
        parallel: true,
        stopOnError: false,
      );

  Map<String, dynamic> toJson() => {
        'parallel': parallel,
        'stopOnError': stopOnError,
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
      };
}
