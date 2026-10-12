import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

/// Utility functions for plugin testing
class PluginTestUtils {
  /// تست اینکه پلاگین اطلاعات درستی برمی‌گردونه
  static Future<void> testPluginInfo(
    Plugin plugin, {
    required String expectedName,
    required String expectedVersion,
  }) async {
    expect(plugin.name, expectedName);
    expect(plugin.version, expectedVersion);
    expect(plugin.supportedMethods, isNotEmpty);
  }

  /// تست اینکه getInfo کار می‌کنه
  static Future<void> testGetInfo(Plugin plugin) async {
    if (plugin.supportsMethod('getInfo')) {
      final result = await plugin.onCall('getInfo', {});
      expect(result, isA<Map>());
      expect(result['name'], plugin.name);
    }
  }

  /// تست اینکه متدهای ناشناخته خطا می‌دن
  static Future<void> testUnsupportedMethod(Plugin plugin) async {
    expect(
      () => plugin.onCall('__nonexistent_method__', {}),
      throwsA(isA<UnsupportedError>()),
    );
  }

  /// تست validation برای یک متد
  static Future<void> testValidation(
    Plugin plugin,
    String method,
    Map<String, dynamic> invalidArgs,
  ) async {
    final result = await plugin.validateArgs(method, invalidArgs);
    expect(result.isValid, false);
    expect(result.errorMessage, isNotEmpty);
  }

  /// تست validation valid
  static Future<void> testValidArgs(
    Plugin plugin,
    String method,
    Map<String, dynamic> validArgs,
  ) async {
    final result = await plugin.validateArgs(method, validArgs);
    expect(result.isValid, true);
  }

  /// تست lifecycle: initialize → call → dispose
  static Future<void> testLifecycle(
    Plugin plugin,
    String method,
    Map<String, dynamic> args,
  ) async {
    await plugin.initialize();
    expect(plugin.isReady, true);

    final result = await plugin.onCall(method, args);
    expect(result, isNotNull);

    await plugin.dispose();
    expect(plugin.isReady, false);
  }

  /// تست double initialize
  static Future<void> testDoubleInitialize(Plugin plugin) async {
    await plugin.initialize();
    await plugin.initialize(); // should not throw
    expect(plugin.isReady, true);
    await plugin.dispose();
  }
}
