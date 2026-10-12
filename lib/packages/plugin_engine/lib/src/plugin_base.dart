import 'dart:async';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'plugin_interface.dart';

typedef PluginEventEmitter = Future<void> Function(String event, dynamic data);

/// Base class بهبودیافته — همه پلاگین‌ها از این ارث ببرن
abstract class BasePlugin extends Plugin {
  /// Event emitter — اختیاری
  PluginEventEmitter? eventEmitter;

  /// دسترسی به AppContext
  AppContext get appContext => AppContext();

  /// دسترسی به BuildContext فعلی
  dynamic get context => appContext.context;

  /// آیا context در دسترس هست
  bool get hasContext => appContext.hasContext;

  /// ارسال event به JS
  Future<void> emitEvent(String event, dynamic data) async {
    if (eventEmitter != null) {
      await eventEmitter!(event, data);
    } else {
      BridgeLogger.warn(
        name,
        'Event emitter not set, dropping event: $event',
      );
    }
  }

  /// اجرای safe یک action با error handling
  Future<Map<String, dynamic>> safeExecute(
    String action,
    Future<Map<String, dynamic>> Function() fn,
  ) async {
    try {
      return await fn();
    } catch (e) {
      BridgeLogger.error(name, '$action failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'action': action,
      };
    }
  }

  /// بررسی context و throw error اگه نبود
  void requireContext() {
    if (!hasContext) {
      throw const PluginException.noContext();
    }
  }

  /// Log helper
  void logInfo(String message) => BridgeLogger.info(name, message);
  void logWarn(String message) => BridgeLogger.warn(name, message);
  void logError(String message) => BridgeLogger.error(name, message);
  void logDebug(String message) => BridgeLogger.debug(name, message);
}
