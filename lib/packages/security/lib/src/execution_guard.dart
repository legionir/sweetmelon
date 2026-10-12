import 'dart:async';
import 'package:sweetmelon/packages/core/lib/core.dart' hide TimeoutException;

class ExecutionGuard {
  final int defaultTimeoutMs;
  final Map<String, int> _activeExecutions = {};

  ExecutionGuard({this.defaultTimeoutMs = 30000});

  Future<T?> execute<T>({
    required String requestId,
    required Future<T> Function() fn,
    int? timeoutMs,
  }) async {
    final timeout = timeoutMs ?? defaultTimeoutMs;

    if (_activeExecutions.containsKey(requestId)) {
      BridgeLogger.warn(
        'ExecutionGuard',
        'Duplicate request detected: $requestId',
      );
    }

    _activeExecutions[requestId] = DateTime.now().millisecondsSinceEpoch;

    try {
      final result = await fn().timeout(
        Duration(milliseconds: timeout),
        onTimeout: () {
          BridgeLogger.warn(
            'ExecutionGuard',
            'Timeout for: $requestId after ${timeout}ms',
          );
          throw TimeoutException(
            'Execution timeout after ${timeout}ms',
          );
        },
      );
      return result;
    } finally {
      _activeExecutions.remove(requestId);
    }
  }

  int get activeCount => _activeExecutions.length;
  List<String> get activeRequests => _activeExecutions.keys.toList();
  bool isActive(String requestId) => _activeExecutions.containsKey(requestId);
}

class ArgsValidator {
  static ArgsValidationResult validate(
    Map<String, dynamic> args,
    Map<String, ArgSchema> schema,
  ) {
    final warnings = <String>[];

    for (final entry in schema.entries) {
      final fieldName = entry.key;
      final fieldSchema = entry.value;

      if (fieldSchema.required && !args.containsKey(fieldName)) {
        return ArgsValidationResult.invalid(
          'Required field "$fieldName" is missing',
        );
      }

      if (args.containsKey(fieldName)) {
        final value = args[fieldName];

        if (!fieldSchema.isValidType(value)) {
          return ArgsValidationResult.invalid(
            'Field "$fieldName" has invalid type. '
            'Expected: ${fieldSchema.type}, '
            'Got: ${value.runtimeType}',
          );
        }

        if (fieldSchema.validator != null) {
          final error = fieldSchema.validator!(value);
          if (error != null) {
            return ArgsValidationResult.invalid(error);
          }
        }
      }
    }

    for (final key in args.keys) {
      if (!schema.containsKey(key)) {
        warnings.add('Unknown field: "$key"');
      }
    }

    if (warnings.isNotEmpty) {
      return ArgsValidationResult.validWithWarnings(warnings);
    }

    return ArgsValidationResult.valid();
  }
}

class ArgSchema {
  final String type;
  final bool required;
  final dynamic defaultValue;
  final String? Function(dynamic value)? validator;

  const ArgSchema({
    required this.type,
    this.required = false,
    this.defaultValue,
    this.validator,
  });

  bool isValidType(dynamic value) {
    if (value == null) return !required;
    switch (type) {
      case 'string':
        return value is String;
      case 'int':
        return value is int;
      case 'double':
        return value is double || value is int;
      case 'num':
        return value is num;
      case 'bool':
        return value is bool;
      case 'list':
        return value is List;
      case 'map':
        return value is Map;
      case 'any':
        return true;
      default:
        return true;
    }
  }
}

class ArgsValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String> warnings;

  const ArgsValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warnings = const [],
  });

  factory ArgsValidationResult.valid() =>
      const ArgsValidationResult(isValid: true);

  factory ArgsValidationResult.invalid(String message) =>
      ArgsValidationResult(isValid: false, errorMessage: message);

  factory ArgsValidationResult.validWithWarnings(List<String> warnings) =>
      ArgsValidationResult(isValid: true, warnings: warnings);
}
