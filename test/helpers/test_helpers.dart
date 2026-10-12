import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/performance/lib/performance.dart';
import 'package:sweetmelon/packages/security/lib/security.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

/// ساخت PluginManager با تنظیمات تست
PluginManager createTestPluginManager({
  PluginRegistry? registry,
  PermissionManager? permissionManager,
  RateLimiter? rateLimiter,
  ExecutionGuard? executionGuard,
  CacheManager? cacheManager,
  LazyPluginLoader? lazyLoader,
}) {
  final reg = registry ?? PluginRegistry();
  final pm = permissionManager ?? _createTestPermissionManager();
  final rl = rateLimiter ?? RateLimiter();
  final eg = executionGuard ?? ExecutionGuard(defaultTimeoutMs: 5000);
  final cm = cacheManager ?? CacheManager(maxEntries: 100);

  return PluginManager(
    registry: reg,
    permissionManager: pm,
    rateLimiter: rl,
    executionGuard: eg,
    cacheManager: cm,
    lazyLoader: lazyLoader,
  );
}

PermissionManager _createTestPermissionManager() {
  final manager = PermissionManager(
    cacheTtl: const Duration(minutes: 30),
  );
  manager.setProvider(
    const StaticPermissionProvider(
      grants: {
        'camera': PermissionStatus.granted,
        'storage': PermissionStatus.granted,
        'location': PermissionStatus.granted,
        'microphone': PermissionStatus.granted,
        'contacts': PermissionStatus.granted,
        'bluetooth': PermissionStatus.granted,
      },
      defaultStatus: PermissionStatus.granted,
    ),
  );
  return manager;
}

/// ساخت PluginRequest برای تست
PluginRequest createTestRequest({
  String plugin = 'mockPlugin',
  String method = 'doSomething',
  Map<String, dynamic>? args,
  String version = '1.0.0',
}) {
  return PluginRequest.create(
    plugin: plugin,
    method: method,
    args: args,
    version: version,
  );
}

/// اجرای چندین request و برگرداندن نتایج
Future<List<PluginResponse>> executeMany(
  PluginManager manager,
  int count, {
  String plugin = 'mockPlugin',
  String method = 'doSomething',
}) async {
  final responses = <PluginResponse>[];

  for (int i = 0; i < count; i++) {
    final request = createTestRequest(
      plugin: plugin,
      method: method,
      args: {'index': i},
    );
    final response = await manager.execute(request);
    responses.add(response);
  }

  return responses;
}

/// بررسی اینکه همه responses موفق بودن
bool allSuccessful(List<PluginResponse> responses) {
  return responses.every((r) => r.success);
}

/// بررسی اینکه همه responses خطا بودن
bool allFailed(List<PluginResponse> responses) {
  return responses.every((r) => !r.success);
}

/// تعداد response‌های موفق
int successCount(List<PluginResponse> responses) {
  return responses.where((r) => r.success).length;
}
