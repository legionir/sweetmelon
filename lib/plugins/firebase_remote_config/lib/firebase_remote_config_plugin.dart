import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef RemoteConfigEventEmitter = Future<void> Function(
  String event,
  dynamic data,
);

class FirebaseRemoteConfigPlugin extends Plugin {
  final RemoteConfigEventEmitter? eventEmitter;

  FirebaseRemoteConfig? _remoteConfig;

  FirebaseRemoteConfigPlugin({this.eventEmitter});

  @override
  String get name => 'firebaseRemoteConfig';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Firebase Remote Config integration';

  @override
  List<String> get supportedMethods => [
        'initialize',
        'fetchAndActivate',
        'fetch',
        'activate',
        'getString',
        'getInt',
        'getDouble',
        'getBool',
        'getJson',
        'getAll',
        'setDefaults',
        'setConfigSettings',
        'getLastFetchTime',
        'getLastFetchStatus',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      BridgeLogger.info('RemoteConfig', 'Initialized');
    } catch (e) {
      BridgeLogger.error('RemoteConfig', 'Init failed: $e');
    }
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'initialize':
        return _initialize(args);
      case 'fetchAndActivate':
        return _fetchAndActivate();
      case 'fetch':
        return _fetch(args);
      case 'activate':
        return _activate();
      case 'getString':
        return _getString(args);
      case 'getInt':
        return _getInt(args);
      case 'getDouble':
        return _getDouble(args);
      case 'getBool':
        return _getBool(args);
      case 'getJson':
        return _getJson(args);
      case 'getAll':
        return _getAll();
      case 'setDefaults':
        return _setDefaults(args);
      case 'setConfigSettings':
        return _setConfigSettings(args);
      case 'getLastFetchTime':
        return _getLastFetchTime();
      case 'getLastFetchStatus':
        return _getLastFetchStatus();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'initialized': _remoteConfig != null,
          'lastFetchStatus': _remoteConfig?.lastFetchStatus.name,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _initialize(Map<String, dynamic> args) async {
    final minimumFetchIntervalMs =
        (args['minimumFetchIntervalMs'] as num?)?.toInt() ?? 3600000;
    final fetchTimeoutMs = (args['fetchTimeoutMs'] as num?)?.toInt() ?? 60000;
    final defaults = args['defaults'] as Map<String, dynamic>? ?? {};

    await _remoteConfig?.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: Duration(milliseconds: fetchTimeoutMs),
        minimumFetchInterval: Duration(milliseconds: minimumFetchIntervalMs),
      ),
    );

    if (defaults.isNotEmpty) {
      await _remoteConfig?.setDefaults(
        defaults.map((key, value) => MapEntry(key, value)),
      );
    }

    return {
      'initialized': true,
      'minimumFetchIntervalMs': minimumFetchIntervalMs,
      'fetchTimeoutMs': fetchTimeoutMs,
    };
  }

  Future<Map<String, dynamic>> _fetchAndActivate() async {
    try {
      final updated = await _remoteConfig?.fetchAndActivate() ?? false;

      BridgeLogger.info(
        'RemoteConfig',
        'Fetched and activated (updated: $updated)',
      );

      if (updated && eventEmitter != null) {
        await eventEmitter!('remoteConfig.updated', {
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      return {'fetched': true, 'activated': true, 'updated': updated};
    } catch (e) {
      BridgeLogger.error('RemoteConfig', 'FetchAndActivate error: $e');
      return {'fetched': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _fetch(Map<String, dynamic> args) async {
    try {
      await _remoteConfig?.fetch();
      return {'fetched': true};
    } catch (e) {
      return {'fetched': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _activate() async {
    final activated = await _remoteConfig?.activate() ?? false;
    return {'activated': activated};
  }

  Map<String, dynamic> _getString(Map<String, dynamic> args) {
    final key = args['key'] as String;
    final value = _remoteConfig?.getString(key) ?? '';
    return {'key': key, 'value': value};
  }

  Map<String, dynamic> _getInt(Map<String, dynamic> args) {
    final key = args['key'] as String;
    final value = _remoteConfig?.getInt(key) ?? 0;
    return {'key': key, 'value': value};
  }

  Map<String, dynamic> _getDouble(Map<String, dynamic> args) {
    final key = args['key'] as String;
    final value = _remoteConfig?.getDouble(key) ?? 0.0;
    return {'key': key, 'value': value};
  }

  Map<String, dynamic> _getBool(Map<String, dynamic> args) {
    final key = args['key'] as String;
    final value = _remoteConfig?.getBool(key) ?? false;
    return {'key': key, 'value': value};
  }

  Map<String, dynamic> _getJson(Map<String, dynamic> args) {
    final key = args['key'] as String;
    final raw = _remoteConfig?.getString(key) ?? '{}';

    try {
      final value = jsonDecode(raw);
      return {'key': key, 'value': value};
    } catch (_) {
      return {'key': key, 'value': null, 'raw': raw};
    }
  }

  Map<String, dynamic> _getAll() {
    final all = _remoteConfig?.getAll() ?? {};
    return {
      'values': all.map(
        (key, value) => MapEntry(key, {
          'source': value.source.name,
          'value': value.asString(),
        }),
      ),
      'count': all.length,
    };
  }

  Future<Map<String, dynamic>> _setDefaults(
    Map<String, dynamic> args,
  ) async {
    final defaults = args['defaults'] as Map<String, dynamic>;
    await _remoteConfig?.setDefaults(
      defaults.map((key, value) => MapEntry(key, value)),
    );
    return {'set': true, 'count': defaults.length};
  }

  Future<Map<String, dynamic>> _setConfigSettings(
    Map<String, dynamic> args,
  ) async {
    final fetchTimeout = (args['fetchTimeoutMs'] as num?)?.toInt() ?? 60000;
    final minimumInterval =
        (args['minimumFetchIntervalMs'] as num?)?.toInt() ?? 3600000;

    await _remoteConfig?.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: Duration(milliseconds: fetchTimeout),
        minimumFetchInterval: Duration(milliseconds: minimumInterval),
      ),
    );

    return {
      'set': true,
      'fetchTimeoutMs': fetchTimeout,
      'minimumFetchIntervalMs': minimumInterval,
    };
  }

  Map<String, dynamic> _getLastFetchTime() {
    final time = _remoteConfig?.lastFetchTime;
    return {
      'timestamp': time?.toIso8601String(),
      'ms': time?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _getLastFetchStatus() {
    final status = _remoteConfig?.lastFetchStatus;
    return {'status': status?.name ?? 'unknown'};
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'getString':
      case 'getInt':
      case 'getDouble':
      case 'getBool':
      case 'getJson':
        if (args['key'] is! String || (args['key'] as String).isEmpty) {
          return ValidationResult.invalid('key is required');
        }
        return ValidationResult.valid();
      case 'setDefaults':
        if (args['defaults'] is! Map) {
          return ValidationResult.invalid('defaults must be a map');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
