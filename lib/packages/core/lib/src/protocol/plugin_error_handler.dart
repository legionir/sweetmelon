import 'message_protocol.dart';
import '../utils/logger.dart';

/// Error handler استاندارد برای همه پلاگین‌ها
class PluginErrorHandler {
  /// تبدیل هر exception به PluginError استاندارد
  static PluginError fromException(Object error, [StackTrace? stackTrace]) {
    if (error is PluginException) {
      return PluginError(
        code: error.code,
        message: error.message,
        details: error.details,
        stackTrace: stackTrace?.toString(),
      );
    }

    if (error is TimeoutException) {
      return PluginError(
        code: PluginErrorCode.timeout,
        message: error.message ?? 'Operation timed out',
        stackTrace: stackTrace?.toString(),
      );
    }

    if (error is FormatException) {
      return PluginError(
        code: PluginErrorCode.invalidArgs,
        message: 'Format error: ${error.message}',
        stackTrace: stackTrace?.toString(),
      );
    }

    if (error is StateError) {
      return PluginError(
        code: PluginErrorCode.executionError,
        message: error.message,
        stackTrace: stackTrace?.toString(),
      );
    }

    if (error is UnsupportedError) {
      return PluginError(
        code: PluginErrorCode.methodNotFound,
        message: error.message ?? 'Unsupported operation',
        stackTrace: stackTrace?.toString(),
      );
    }

    final message = error.toString();

    // Network errors
    if (_isNetworkError(message)) {
      return PluginError(
        code: PluginErrorCode.networkError,
        message: message,
        stackTrace: stackTrace?.toString(),
      );
    }

    // Permission errors
    if (_isPermissionError(message)) {
      return PluginError(
        code: PluginErrorCode.permissionDenied,
        message: message,
        stackTrace: stackTrace?.toString(),
      );
    }

    return PluginError(
      code: PluginErrorCode.executionError,
      message: message,
      stackTrace: stackTrace?.toString(),
    );
  }

  /// ساخت response خطا از exception
  static PluginResponse errorResponse(
    String requestId,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    return PluginResponse.failure(
      requestId: requestId,
      error: fromException(error, stackTrace),
    );
  }

  /// اجرای یک action با error handling خودکار
  static Future<PluginResponse> execute(
    String requestId,
    String pluginName,
    String method,
    Future<dynamic> Function() action,
  ) async {
    try {
      final result = await action();
      return PluginResponse.success(
        requestId: requestId,
        data: result,
      );
    } catch (e, stackTrace) {
      BridgeLogger.error(
        pluginName,
        '$method error: $e',
      );
      return errorResponse(requestId, e, stackTrace);
    }
  }

  static bool _isNetworkError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('network is unreachable') ||
        lower.contains('no address associated') ||
        lower.contains('connection timed out');
  }

  static bool _isPermissionError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('permission') ||
        lower.contains('denied') ||
        lower.contains('not allowed');
  }
}

/// Exception سفارشی با error code
class PluginException implements Exception {
  final PluginErrorCode code;
  final String message;
  final Map<String, dynamic>? details;

  const PluginException({
    required this.code,
    required this.message,
    this.details,
  });

  /// Factories for common errors
  const PluginException.notFound(String what)
      : code = PluginErrorCode.pluginNotFound,
        message = '$what not found',
        details = null;

  const PluginException.invalidArgs(String reason)
      : code = PluginErrorCode.invalidArgs,
        message = reason,
        details = null;

  const PluginException.permissionDenied(String permission)
      : code = PluginErrorCode.permissionDenied,
        message = 'Permission denied: $permission',
        details = null;

  const PluginException.noContext()
      : code = PluginErrorCode.executionError,
        message = 'No UI context available',
        details = null;

  @override
  String toString() => 'PluginException(${code.code}): $message';
}

/// Import helper
class TimeoutException implements Exception {
  final String? message;
  const TimeoutException([this.message]);
}
