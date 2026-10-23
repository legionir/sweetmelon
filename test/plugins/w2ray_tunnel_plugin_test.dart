import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/plugins/w2ray_tunnel/lib/w2ray_tunnel_plugin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(W2rayTunnelPlugin.channelName);
  late List<MethodCall> calls;
  late List<String> events;
  late Object? Function(MethodCall) answer;
  late W2rayTunnelPlugin plugin;

  setUp(() {
    calls = [];
    events = [];
    answer = (_) => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final value = answer(call);
      if (value is PlatformException) throw value;
      return value;
    });
    // The event channel has no handler: listening fails quietly, as on a
    // platform without the module.
    plugin = W2rayTunnelPlugin(eventEmitter: (event, data) async {
      events.add('$event:${jsonEncode(data)}');
    });
  });

  tearDown(() async {
    await plugin.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('start sends the settings as one JSON string', () async {
    final config = {
      'url': 'wss://example.com:4431/api/stream',
      'password': 'secret',
      'share': {'enabled': true, 'port': 1080},
    };
    expect(await plugin.onCall('start', {'config': config}), isTrue);
    expect(calls.single.method, 'start');
    final sent = calls.single.arguments as Map;
    expect(jsonDecode(sent['config'] as String), config);
  });

  test('a JSON string is passed on as it is', () async {
    await plugin.onCall('test', {'config': '{"password":"p"}', 'deep': true});
    final sent = calls.single.arguments as Map;
    expect(sent['config'], '{"password":"p"}');
    expect(sent['deep'], isTrue);
  });

  test('start and setShare need their settings', () async {
    expect(plugin.onCall('start', {}), throwsArgumentError);
    expect(plugin.onCall('setShare', {}), throwsArgumentError);
    expect(calls, isEmpty);
  });

  test('setShare sends the share settings as JSON', () async {
    await plugin.onCall('setShare', {
      'share': {'enabled': false}
    });
    expect(calls.single.method, 'setShare');
    expect(jsonDecode((calls.single.arguments as Map)['share'] as String),
        {'enabled': false});
  });

  test('results come back with string keys', () async {
    answer = (_) => {
          'state': 'connected',
          'share': {'enabled': true, 'clients': ['192.168.1.5']},
        };
    final status = await plugin.onCall('status', {}) as Map;
    expect(status['state'], 'connected');
    expect((status['share'] as Map)['clients'], ['192.168.1.5']);
  });

  test('native errors keep their code and message', () async {
    answer = (_) => PlatformException(code: 'TUNNEL', message: 'refused');
    try {
      await plugin.onCall('start', {'config': '{}'});
      fail('should throw');
    } on PluginException catch (e) {
      expect(e.message, 'refused');
      expect(e.details?['nativeCode'], 'TUNNEL');
    }
  });

  test('a build without the module says so', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    try {
      await plugin.onCall('status', {});
      fail('should throw');
    } on PluginException catch (e) {
      expect(e.details?['nativeCode'], 'UNAVAILABLE');
    }
  });

  test('native events become w2rayTunnel.<type> events', () {
    plugin.handleEvent({'type': 'state', 'state': 'connected', 'mode': 'vpn'});
    plugin.handleEvent({'type': 'log', 'level': 'I', 'message': 'hi'});
    plugin.handleEvent({'type': 'stats', 'rx': 1, 'tx': 2});
    plugin.handleEvent({'type': 'other'});
    plugin.handleEvent('not a map');
    expect(events, [
      'w2rayTunnel.state:{"state":"connected","mode":"vpn"}',
      'w2rayTunnel.log:{"level":"I","message":"hi"}',
      'w2rayTunnel.stats:{"rx":1,"tx":2}',
    ]);
  });

  test('unknown methods are refused', () async {
    expect(plugin.onCall('nope', {}), throwsUnsupportedError);
    expect(plugin.supportsMethod('start'), isTrue);
    expect(plugin.supportsMethod('nope'), isFalse);
  });

  test('getInfo reports the native side', () async {
    answer = (call) => call.method == 'info' ? {'version': '1.0.0'} : null;
    final info = await plugin.onCall('getInfo', {}) as Map;
    expect(info['name'], 'w2rayTunnel');
    expect((info['native'] as Map)['version'], '1.0.0');
  });
}
