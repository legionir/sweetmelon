import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart' as cp;
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef ConnectivityEventEmitter = Future<void> Function(
  String event,
  dynamic data,
);

class ConnectivityBridgePlugin extends Plugin {
  final cp.Connectivity _connectivity = cp.Connectivity();
  final ConnectivityEventEmitter? eventEmitter;

  StreamSubscription<dynamic>? _subscription;

  ConnectivityBridgePlugin({
    this.eventEmitter,
  });

  @override
  String get name => 'connectivity';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Network connectivity plugin';

  @override
  List<String> get supportedMethods => [
        'getStatus',
        'isOnline',
        'startWatch',
        'stopWatch',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getStatus':
        return _getStatus();
      case 'isOnline':
        final status = await _getStatus();
        return {'online': status['online']};
      case 'startWatch':
        return _startWatch();
      case 'stopWatch':
        return _stopWatch();
      case 'getInfo':
        return {
          'watching': _subscription != null,
          'eventName': 'connectivity.change',
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _getStatus() async {
    final dynamic raw = await _connectivity.checkConnectivity();
    final results = _normalizeResults(raw);
    return _buildPayload(results);
  }

  Future<Map<String, dynamic>> _startWatch() async {
    if (_subscription != null) {
      return {
        'watching': true,
        'alreadyWatching': true,
      };
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      (dynamic raw) async {
        final results = _normalizeResults(raw);
        final payload = _buildPayload(results);

        BridgeLogger.info(
          'Connectivity',
          'Connectivity changed: ${payload['types']}',
        );

        if (eventEmitter != null) {
          await eventEmitter!('connectivity.change', payload);
        }
      },
      onError: (error) async {
        BridgeLogger.error('Connectivity', 'Watch error: $error');
        if (eventEmitter != null) {
          await eventEmitter!(
            'connectivity.error',
            {
              'message': error.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      },
    );

    final initial = await _getStatus();
    if (eventEmitter != null) {
      await eventEmitter!('connectivity.change', initial);
    }

    return {
      'watching': true,
      'alreadyWatching': false,
    };
  }

  Future<Map<String, dynamic>> _stopWatch() async {
    await _subscription?.cancel();
    _subscription = null;
    return {'watching': false};
  }

  List<cp.ConnectivityResult> _normalizeResults(dynamic raw) {
    if (raw is cp.ConnectivityResult) {
      return [raw];
    }

    if (raw is List<cp.ConnectivityResult>) {
      return raw;
    }

    if (raw is List) {
      return raw.whereType<cp.ConnectivityResult>().toList();
    }

    return [cp.ConnectivityResult.none];
  }

  Map<String, dynamic> _buildPayload(List<cp.ConnectivityResult> results) {
    final normalized = results.isEmpty ? [cp.ConnectivityResult.none] : results;

    final online = normalized.any((e) => e != cp.ConnectivityResult.none);

    return {
      'online': online,
      'primary': _pickPrimary(normalized).name,
      'types': normalized.map((e) => e.name).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  cp.ConnectivityResult _pickPrimary(List<cp.ConnectivityResult> results) {
    const priority = [
      cp.ConnectivityResult.wifi,
      cp.ConnectivityResult.mobile,
      cp.ConnectivityResult.ethernet,
      cp.ConnectivityResult.bluetooth,
      cp.ConnectivityResult.vpn,
      cp.ConnectivityResult.other,
      cp.ConnectivityResult.none,
    ];

    for (final item in priority) {
      if (results.contains(item)) return item;
    }

    return cp.ConnectivityResult.none;
  }

  @override
  Future<void> onDispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
