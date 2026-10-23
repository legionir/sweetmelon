import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef W2rayEventEmitter = Future<void> Function(String event, dynamic data);

/// Connects the phone to a w2ray tunnel server (`src/tunnel` of the w2ray
/// project, a WebSocket tunnel) as a system-wide VPN, and shares that
/// connection as a SOCKS5 proxy for other devices.
///
/// The work is native (Android): `android/w2ray_tunnel` holds the VPN service,
/// the tunnel engine and hev-socks5-tunnel. The module is part of the build only
/// when this plugin is enabled in sweetmelon.yaml.
class W2rayTunnelPlugin extends Plugin {
  W2rayTunnelPlugin({
    this.eventEmitter,
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methods = methodChannel ?? const MethodChannel(channelName),
        _events = eventChannel ?? const EventChannel(eventChannelName);

  static const channelName = 'sweetmelon/w2ray_tunnel';
  static const eventChannelName = 'sweetmelon/w2ray_tunnel/events';

  final W2rayEventEmitter? eventEmitter;
  final MethodChannel _methods;
  final EventChannel _events;
  StreamSubscription<dynamic>? _subscription;

  @override
  String get name => 'w2rayTunnel';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'VPN and SOCKS5 sharing through a w2ray WebSocket tunnel';

  @override
  List<String> get supportedMethods => [
        'prepare',
        'start',
        'stop',
        'status',
        'logs',
        'clearLogs',
        'setShare',
        'addresses',
        'apps',
        'appIcon',
        'test',
        'netInfo',
        'openVpnSettings',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    _listen();
    switch (method) {
      case 'getInfo':
        final native = await _invoke('info', const {});
        return {'name': name, 'version': version, 'native': native};
      case 'start':
      case 'test':
        return _invoke(method, {...args, 'config': _config(args)});
      case 'setShare':
        return _invoke(method, {'share': _share(args)});
      case 'prepare':
      case 'stop':
      case 'status':
      case 'logs':
      case 'clearLogs':
      case 'addresses':
      case 'apps':
      case 'appIcon':
      case 'netInfo':
      case 'openVpnSettings':
        return _invoke(method, args);
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  /// The settings travel as one JSON string: the native side parses and
  /// checks them in one place, whatever the caller sent.
  String _config(Map<String, dynamic> args) {
    final config = args['config'];
    if (config is String) return config;
    if (config is Map) return jsonEncode(config);
    throw ArgumentError('config is required');
  }

  String _share(Map<String, dynamic> args) {
    final share = args['share'];
    if (share is String) return share;
    if (share is Map) return jsonEncode(share);
    throw ArgumentError('share is required');
  }

  Future<dynamic> _invoke(String method, Map<String, dynamic> args) async {
    try {
      final result = await _methods.invokeMethod<dynamic>(method, args);
      return _plain(result);
    } on PlatformException catch (e) {
      throw PluginException(
        code: PluginErrorCode.executionError,
        message: e.message ?? e.code,
        details: {'nativeCode': e.code},
      );
    } on MissingPluginException {
      throw const PluginException(
        code: PluginErrorCode.executionError,
        message: 'w2rayTunnel works on Android only',
        details: {'nativeCode': 'UNAVAILABLE'},
      );
    }
  }

  /// Booleans, numbers and strings pass; maps and lists are copied with string keys.
  dynamic _plain(dynamic value) {
    if (value is Map) {
      return {for (final e in value.entries) e.key.toString(): _plain(e.value)};
    }
    if (value is List) return [for (final e in value) _plain(e)];
    return value;
  }

  void _listen() {
    if (_subscription != null) return;
    try {
      _subscription = _events.receiveBroadcastStream().listen(
        handleEvent,
        onError: (Object error) {
          BridgeLogger.error('W2rayTunnel', 'Event stream error: $error');
        },
      );
    } catch (e) {
      BridgeLogger.warn('W2rayTunnel', 'Native events not available: $e');
    }
  }

  /// Turns a native event into the JS event `w2rayTunnel.<type>`.
  /// `state`, `log` and `stats` are the types the native side sends.
  void handleEvent(dynamic raw) {
    if (raw is! Map) return;
    final data = _plain(raw) as Map<String, dynamic>;
    final type = data.remove('type');
    if (type is! String || !_eventTypes.contains(type)) return;
    eventEmitter?.call('w2rayTunnel.$type', data);
  }

  static const _eventTypes = {'state', 'log', 'stats'};
}
