import 'dart:async';
import 'dart:convert';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/performance/lib/performance.dart';
import 'package:sweetmelon/packages/security/lib/security.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class PluginManager {
  final PluginRegistry registry;
  final PermissionManager permissionManager;
  final RateLimiter rateLimiter;
  final ExecutionGuard executionGuard;
  final CacheManager cacheManager;
  final CircuitBreakerRegistry circuitBreakers;

  /// Lazy loader — اختیاری
  LazyPluginLoader? lazyLoader;

  final Map<String, PluginStats> _stats = {};
  final _traceController = StreamController<PluginTrace>.broadcast();
  bool _disposed = false;

  Stream<PluginTrace> get traces => _traceController.stream;

  PluginManager({
    required this.registry,
    required this.permissionManager,
    required this.rateLimiter,
    required this.executionGuard,
    required this.cacheManager,
    CircuitBreakerRegistry? circuitBreakers,
    this.lazyLoader,
  }) : circuitBreakers = circuitBreakers ?? CircuitBreakerRegistry();

  /// ست کردن lazy loader
  void setLazyLoader(LazyPluginLoader loader) {
    lazyLoader = loader;
  }

  Future<PluginResponse> execute(PluginRequest request) async {
    if (_disposed) {
      return _errorResponse(
        request.requestId,
        PluginErrorCode.executionError,
        'PluginManager is disposed',
      );
    }

    final startTime = DateTime.now();
    final traceId = 'trace_${request.requestId}';
    final pluginKey = request.plugin;

    BridgeLogger.info(
      'Manager',
      'Executing: ${request.plugin}.${request.method}',
    );

    try {
      // Circuit Breaker check
      final breaker = circuitBreakers.get(pluginKey);
      if (!breaker.isAllowed) {
        return _errorResponse(
          request.requestId,
          PluginErrorCode.executionError,
          'Circuit breaker open for "${request.plugin}"',
        );
      }

      // Rate limit
      final rateLimitResult = await rateLimiter.check(
        request.plugin,
        request.method,
      );
      if (!rateLimitResult.allowed) {
        return _errorResponse(
          request.requestId,
          PluginErrorCode.rateLimitExceeded,
          'Rate limit exceeded. Retry after ${rateLimitResult.retryAfterMs}ms',
        );
      }

      // ═══ Resolve plugin — with lazy loading ═══
      var plugin = registry.resolve(
        request.plugin,
        version: request.version == '1.0.0' ? null : request.version,
      );

      // پلاگین وجود ندارد — بررسی lazy loading
      if (plugin == null && lazyLoader != null) {
        if (lazyLoader!.canLoad(request.plugin)) {
          BridgeLogger.info(
            'Manager',
            'Lazy loading plugin: ${request.plugin}',
          );

          try {
            plugin = await lazyLoader!.load(request.plugin);
          } catch (e) {
            BridgeLogger.error(
              'Manager',
              'Lazy load failed: ${request.plugin} — $e',
            );
            return _errorResponse(
              request.requestId,
              PluginErrorCode.pluginNotFound,
              'Plugin "${request.plugin}" failed to load: $e',
            );
          }
        }
      }

      if (plugin == null) {
        return _errorResponse(
          request.requestId,
          PluginErrorCode.pluginNotFound,
          'Plugin "${request.plugin}" not found',
        );
      }

      // پلاگین هست ولی initialize نشده
      if (!plugin.isReady) {
        BridgeLogger.info(
          'Manager',
          'Auto-initializing plugin: ${request.plugin}',
        );
        await plugin.initialize();
      }

      // Method check
      if (!plugin.supportsMethod(request.method)) {
        return _errorResponse(
          request.requestId,
          PluginErrorCode.methodNotFound,
          'Method "${request.method}" not supported by "${request.plugin}"',
        );
      }

      // Permission check
      for (final permission in plugin.requiredPermissions) {
        final hasPermission = await permissionManager.check(permission);
        if (!hasPermission) {
          return _errorResponse(
            request.requestId,
            PluginErrorCode.permissionDenied,
            'Permission "$permission" denied',
          );
        }
      }

      // Validate args
      final validation = await plugin.validateArgs(
        request.method,
        request.args,
      );
      if (!validation.isValid) {
        return _errorResponse(
          request.requestId,
          PluginErrorCode.invalidArgs,
          validation.errorMessage ?? 'Invalid arguments',
        );
      }

      // Cache check
      final isMutation = cacheManager.isMutationMethod(request.method);

      if (plugin.cacheable && !isMutation) {
        final cacheKey = _buildCacheKey(request);
        final cached = await cacheManager.get(cacheKey);
        if (cached != null) {
          _recordStats(request.plugin, request.method, 0, true);
          return PluginResponse.success(
            requestId: request.requestId,
            data: cached,
            metadata: ResponseMetadata(
              processingTimeMs: 0,
              pluginVersion: plugin.version,
              fromCache: true,
            ),
          );
        }
      }

      // Execute with circuit breaker
      final result = await breaker.execute(() async {
        return await executionGuard.execute(
          requestId: request.requestId,
          timeoutMs: 30000,
          fn: () => plugin!.onCall(request.method, request.args),
        );
      });

      final processingTime =
          DateTime.now().difference(startTime).inMilliseconds;

      if (plugin.cacheable && !isMutation && result != null) {
        final cacheKey = _buildCacheKey(request);
        await cacheManager.set(cacheKey, result, ttl: plugin.defaultCacheTtl);
      }

      if (plugin.cacheable && isMutation) {
        await cacheManager.invalidatePlugin(request.plugin);
      }

      _recordStats(request.plugin, request.method, processingTime, false);

      _emitTrace(
        traceId: traceId,
        requestId: request.requestId,
        plugin: request.plugin,
        method: request.method,
        processingTimeMs: processingTime,
        success: true,
      );

      return PluginResponse.success(
        requestId: request.requestId,
        data: result,
        metadata: ResponseMetadata(
          processingTimeMs: processingTime,
          pluginVersion: plugin.version,
          fromCache: false,
        ),
      );
    } on CircuitBreakerOpenException catch (e) {
      return _errorResponse(
        request.requestId,
        PluginErrorCode.executionError,
        e.toString(),
      );
    } catch (e, stackTrace) {
      final processingTime =
          DateTime.now().difference(startTime).inMilliseconds;

      _emitTrace(
        traceId: traceId,
        requestId: request.requestId,
        plugin: request.plugin,
        method: request.method,
        processingTimeMs: processingTime,
        success: false,
        error: e.toString(),
      );

      if (e is TimeoutException) {
        return _errorResponse(
          request.requestId,
          PluginErrorCode.timeout,
          'Plugin execution timed out',
        );
      }

      return _errorResponse(
        request.requestId,
        PluginErrorCode.executionError,
        e.toString(),
        stackTrace: stackTrace.toString(),
      );
    }
  }

  Future<List<PluginResponse>> executeBatch(
    List<PluginRequest> requests,
    BatchOptions options,
  ) async {
    if (options.parallel) {
      final futures = requests.map((request) async {
        try {
          return await execute(request);
        } catch (e) {
          return PluginResponse.failure(
            requestId: request.requestId,
            error: PluginError(
              code: PluginErrorCode.executionError,
              message: e.toString(),
            ),
          );
        }
      }).toList();

      final results = await Future.wait(futures);

      if (options.stopOnError) {
        final firstError = results.indexWhere((r) => !r.success);
        if (firstError >= 0) {
          return results.sublist(0, firstError + 1);
        }
      }

      return results;
    } else {
      final responses = <PluginResponse>[];
      for (final request in requests) {
        final response = await execute(request);
        responses.add(response);
        if (options.stopOnError && !response.success) break;
      }
      return responses;
    }
  }

  Map<String, dynamic> get circuitBreakerStats => circuitBreakers.allStats;
  void resetCircuitBreaker(String plugin) => circuitBreakers.reset(plugin);
  void resetAllCircuitBreakers() => circuitBreakers.resetAll();

  PluginResponse _errorResponse(
    String requestId,
    PluginErrorCode code,
    String message, {
    String? stackTrace,
  }) {
    return PluginResponse.failure(
      requestId: requestId,
      error: PluginError(
        code: code,
        message: message,
        stackTrace: stackTrace,
      ),
    );
  }

  String _buildCacheKey(PluginRequest request) {
    final sortedArgs = _sortedJsonEncode(request.args);
    return '${request.plugin}:${request.method}:$sortedArgs';
  }

  String _sortedJsonEncode(Map<String, dynamic> map) {
    final sortedKeys = map.keys.toList()..sort();
    final sortedMap = <String, dynamic>{};
    for (final key in sortedKeys) {
      final value = map[key];
      if (value is Map<String, dynamic>) {
        sortedMap[key] = jsonDecode(_sortedJsonEncode(value));
      } else {
        sortedMap[key] = value;
      }
    }
    return jsonEncode(sortedMap);
  }

  void _recordStats(String plugin, String method, int timeMs, bool fromCache) {
    final key = '$plugin.$method';
    _stats[key] ??= PluginStats(plugin: plugin, method: method);
    _stats[key]!.record(timeMs, fromCache);
  }

  void _emitTrace({
    required String traceId,
    required String requestId,
    required String plugin,
    required String method,
    required int processingTimeMs,
    required bool success,
    bool fromCache = false,
    String? error,
  }) {
    if (!_traceController.isClosed) {
      _traceController.add(PluginTrace(
        traceId: traceId,
        requestId: requestId,
        plugin: plugin,
        method: method,
        processingTimeMs: processingTimeMs,
        success: success,
        fromCache: fromCache,
        error: error,
      ));
    }
  }

  Map<String, PluginStats> get stats => Map.unmodifiable(_stats);

  void dispose() {
    _disposed = true;
    if (!_traceController.isClosed) {
      _traceController.close();
    }
  }
}

class PluginStats {
  final String plugin;
  final String method;
  int totalCalls = 0;
  int cacheHits = 0;
  int totalTimeMs = 0;
  int errorCount = 0;

  PluginStats({required this.plugin, required this.method});

  void record(int timeMs, bool fromCache) {
    totalCalls++;
    totalTimeMs += timeMs;
    if (fromCache) cacheHits++;
  }

  void recordError() => errorCount++;
  double get avgTimeMs => totalCalls > 0 ? totalTimeMs / totalCalls : 0;
  double get cacheHitRate => totalCalls > 0 ? cacheHits / totalCalls : 0;

  Map<String, dynamic> toJson() => {
        'plugin': plugin,
        'method': method,
        'totalCalls': totalCalls,
        'cacheHits': cacheHits,
        'cacheHitRate': cacheHitRate,
        'avgTimeMs': avgTimeMs,
        'errorCount': errorCount,
      };
}

class PluginTrace {
  final String traceId;
  final String requestId;
  final String plugin;
  final String method;
  final int processingTimeMs;
  final bool success;
  final bool fromCache;
  final String? error;
  final DateTime timestamp;

  PluginTrace({
    required this.traceId,
    required this.requestId,
    required this.plugin,
    required this.method,
    required this.processingTimeMs,
    required this.success,
    this.fromCache = false,
    this.error,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
        'traceId': traceId,
        'requestId': requestId,
        'plugin': plugin,
        'method': method,
        'processingTimeMs': processingTimeMs,
        'success': success,
        'fromCache': fromCache,
        if (error != null) 'error': error,
        'timestamp': timestamp.toIso8601String(),
      };
}
