import 'dart:async';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'plugin_interface.dart';
import 'plugin_registry.dart';

/// Factory function for creating plugin instances
typedef PluginFactory = Plugin Function();

/// تعریف یک پلاگین lazy
class LazyPluginDefinition {
  final String id;
  final String version;
  final PluginFactory factory;
  final bool autoInitialize;
  final List<String> dependencies;

  const LazyPluginDefinition({
    required this.id,
    required this.version,
    required this.factory,
    this.autoInitialize = false,
    this.dependencies = const [],
  });
}

/// وضعیت یک پلاگین lazy
enum LazyPluginState {
  unloaded,
  loading,
  loaded,
  failed,
}

class LazyPluginStatus {
  final String id;
  final LazyPluginState state;
  final DateTime? loadedAt;
  final Duration? loadDuration;
  final String? error;

  const LazyPluginStatus({
    required this.id,
    required this.state,
    this.loadedAt,
    this.loadDuration,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'state': state.name,
        'loadedAt': loadedAt?.toIso8601String(),
        'loadDurationMs': loadDuration?.inMilliseconds,
        if (error != null) 'error': error,
      };
}

class LazyPluginLoader {
  final PluginRegistry registry;
  final Map<String, LazyPluginDefinition> _definitions = {};
  final Map<String, LazyPluginStatus> _statuses = {};
  final Map<String, Completer<Plugin>> _loadingCompleters = {};

  LazyPluginLoader({required this.registry});

  /// ثبت یک پلاگین به صورت lazy
  void register(LazyPluginDefinition definition) {
    _definitions[definition.id] = definition;
    _statuses[definition.id] = LazyPluginStatus(
      id: definition.id,
      state: LazyPluginState.unloaded,
    );

    BridgeLogger.debug(
      'LazyLoader',
      'Registered lazy plugin: ${definition.id}@${definition.version}',
    );
  }

  /// ثبت چندین پلاگین
  void registerAll(List<LazyPluginDefinition> definitions) {
    for (final def in definitions) {
      register(def);
    }
  }

  /// آیا این پلاگین قابل load شدن هست؟
  bool canLoad(String pluginId) {
    return _definitions.containsKey(pluginId);
  }

  /// آیا پلاگین load شده؟
  bool isLoaded(String pluginId) {
    return _statuses[pluginId]?.state == LazyPluginState.loaded;
  }

  /// بارگذاری یک پلاگین
  Future<Plugin> load(String pluginId) async {
    // اگه قبلاً load شده، از registry برگردون
    final existing = registry.resolve(pluginId);
    if (existing != null && existing.isReady) {
      return existing;
    }

    // اگه در حال load شدن هست، منتظر بمون
    if (_loadingCompleters.containsKey(pluginId)) {
      BridgeLogger.debug(
        'LazyLoader',
        'Already loading: $pluginId, waiting...',
      );
      return _loadingCompleters[pluginId]!.future;
    }

    final definition = _definitions[pluginId];
    if (definition == null) {
      throw StateError(
        'Plugin "$pluginId" is not registered as lazy plugin',
      );
    }

    // شروع loading
    final completer = Completer<Plugin>();
    _loadingCompleters[pluginId] = completer;

    _statuses[pluginId] = LazyPluginStatus(
      id: pluginId,
      state: LazyPluginState.loading,
    );

    final stopwatch = Stopwatch()..start();

    try {
      BridgeLogger.info('LazyLoader', 'Loading plugin: $pluginId');

      // اول dependency ها رو load کن
      for (final depId in definition.dependencies) {
        if (!isLoaded(depId) && canLoad(depId)) {
          BridgeLogger.debug(
            'LazyLoader',
            'Loading dependency: $depId for $pluginId',
          );
          await load(depId);
        }
      }

      // ساخت instance
      final plugin = definition.factory();

      // ثبت در registry
      await registry.register(plugin);

      stopwatch.stop();

      _statuses[pluginId] = LazyPluginStatus(
        id: pluginId,
        state: LazyPluginState.loaded,
        loadedAt: DateTime.now(),
        loadDuration: stopwatch.elapsed,
      );

      BridgeLogger.info(
        'LazyLoader',
        'Plugin loaded: $pluginId (${stopwatch.elapsedMilliseconds}ms)',
      );

      completer.complete(plugin);
    } catch (e, stackTrace) {
      stopwatch.stop();

      _statuses[pluginId] = LazyPluginStatus(
        id: pluginId,
        state: LazyPluginState.failed,
        error: e.toString(),
      );

      BridgeLogger.error(
        'LazyLoader',
        'Failed to load plugin: $pluginId — $e',
      );

      completer.completeError(e, stackTrace);
    } finally {
      _loadingCompleters.remove(pluginId);
    }

    // One shared future carries the result (or the error) to every caller,
    // including concurrent loads that joined while this load was in flight.
    return completer.future;
  }

  /// Unload کردن پلاگین
  Future<void> unload(String pluginId) async {
    if (!isLoaded(pluginId)) return;

    await registry.unregister(pluginId);

    _statuses[pluginId] = LazyPluginStatus(
      id: pluginId,
      state: LazyPluginState.unloaded,
    );

    BridgeLogger.info('LazyLoader', 'Unloaded plugin: $pluginId');
  }

  /// Reload کردن پلاگین
  Future<Plugin> reload(String pluginId) async {
    BridgeLogger.info('LazyLoader', 'Reloading plugin: $pluginId');
    await unload(pluginId);
    return load(pluginId);
  }

  /// Load کردن همه پلاگین‌هایی که autoInitialize دارن
  Future<void> loadAutoInitPlugins() async {
    final autoPlugins =
        _definitions.values.where((d) => d.autoInitialize).toList();

    BridgeLogger.info(
      'LazyLoader',
      'Auto-loading ${autoPlugins.length} plugins',
    );

    for (final def in autoPlugins) {
      try {
        await load(def.id);
      } catch (e) {
        BridgeLogger.error(
          'LazyLoader',
          'Failed to auto-load: ${def.id} — $e',
        );
      }
    }
  }

  /// Load کردن لیستی از پلاگین‌ها به صورت parallel
  Future<List<Plugin>> loadMany(List<String> pluginIds) async {
    final futures = pluginIds.map((id) async {
      try {
        return await load(id);
      } catch (e) {
        BridgeLogger.error('LazyLoader', 'Failed to load: $id — $e');
        return null;
      }
    }).toList();

    final results = await Future.wait(futures);
    return results.whereType<Plugin>().toList();
  }

  /// Preload بدون block کردن
  void preload(List<String> pluginIds) {
    for (final id in pluginIds) {
      if (!isLoaded(id) && canLoad(id)) {
        _preloadOne(id);
      }
    }
  }

  Future<void> _preloadOne(String id) async {
    try {
      await load(id);
    } catch (e) {
      BridgeLogger.warn('LazyLoader', 'Preload failed: $id — $e');
    }
  }

  /// وضعیت همه پلاگین‌ها
  Map<String, LazyPluginStatus> get allStatuses => Map.unmodifiable(_statuses);

  /// لیست پلاگین‌های unloaded
  List<String> get unloadedPlugins => _statuses.entries
      .where((e) => e.value.state == LazyPluginState.unloaded)
      .map((e) => e.key)
      .toList();

  /// لیست پلاگین‌های loaded
  List<String> get loadedPlugins => _statuses.entries
      .where((e) => e.value.state == LazyPluginState.loaded)
      .map((e) => e.key)
      .toList();

  /// آمار
  Map<String, dynamic> get stats => {
        'total': _definitions.length,
        'loaded': loadedPlugins.length,
        'unloaded': unloadedPlugins.length,
        'loading': _loadingCompleters.length,
        'plugins': _statuses.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      };

  Future<void> dispose() async {
    for (final id in loadedPlugins) {
      await unload(id);
    }
    _definitions.clear();
    _statuses.clear();
  }
}
