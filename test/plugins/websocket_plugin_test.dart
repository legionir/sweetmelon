import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/websocket/lib/websocket_plugin.dart';

void main() {
  group('WebSocketPlugin', () {
    late WebSocketPlugin plugin;
    final List<Map<String, dynamic>> events = [];

    setUp(() async {
      events.clear();
      plugin = WebSocketPlugin(
        eventEmitter: (event, data) async {
          events.add({'event': event, 'data': data});
        },
      );
      await plugin.initialize();
    });

    tearDown(() async {
      await plugin.dispose();
    });

    test('validates connect url', () async {
      final r1 = await plugin.validateArgs('connect', {});
      expect(r1.isValid, false);

      final r2 = await plugin.validateArgs('connect', {'url': 'http://bad'});
      expect(r2.isValid, false);

      final r3 = await plugin.validateArgs('connect', {'url': 'wss://ok.com'});
      expect(r3.isValid, true);
    });

    test('validates send requires id and data', () async {
      final r1 = await plugin.validateArgs('send', {});
      expect(r1.isValid, false);

      final r2 = await plugin.validateArgs('send', {'id': 'x'});
      expect(r2.isValid, false);

      final r3 = await plugin.validateArgs('send', {'id': 'x', 'data': 'hi'});
      expect(r3.isValid, true);
    });

    test('getConnections returns empty initially', () async {
      final result = await plugin.onCall('getConnections', {});
      expect(result['count'], 0);
      expect(result['connections'], isEmpty);
    });

    test('getInfo returns plugin info', () async {
      final result = await plugin.onCall('getInfo', {});
      expect(result['name'], 'websocket');
      expect(result['version'], '1.0.0');
      expect(result['activeConnections'], 0);
    });

    test('disconnect returns not_found for unknown id', () async {
      final result = await plugin.onCall('disconnect', {'id': 'unknown'});
      expect(result['disconnected'], false);
      expect(result['reason'], 'not_found');
    });

    test('send returns not_connected for unknown id', () async {
      final result = await plugin.onCall('send', {
        'id': 'unknown',
        'data': 'hello',
      });
      expect(result['sent'], false);
      expect(result['reason'], 'not_connected');
    });

    test('getState returns not exists for unknown id', () async {
      final result = await plugin.onCall('getState', {'id': 'unknown'});
      expect(result['exists'], false);
    });
  });
}
