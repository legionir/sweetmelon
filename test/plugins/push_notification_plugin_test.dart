import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/push_notification/lib/push_notification_plugin.dart';

void main() {
  group('PushNotificationPlugin', () {
    late PushNotificationPlugin plugin;
    final events = <Map<String, dynamic>>[];

    setUp(() async {
      events.clear();
      plugin = PushNotificationPlugin(
        eventEmitter: (event, data) async {
          events.add({'event': event, 'data': data});
        },
      );
      await plugin.initialize();
    });

    test('register returns token', () async {
      final r = await plugin.onCall('register', {});
      expect(r['registered'], true);
      expect(r['token'], isNotEmpty);
    });

    test('getToken after register', () async {
      await plugin.onCall('register', {});
      final r = await plugin.onCall('getToken', {});
      expect(r['token'], isNotEmpty);
    });

    test('subscribe validates topic', () async {
      final r = await plugin.validateArgs('subscribe', {});
      expect(r.isValid, false);

      final r2 = await plugin.validateArgs('subscribe', {'topic': 'news'});
      expect(r2.isValid, true);
    });

    test('subscribe emits event', () async {
      await plugin.onCall('register', {});
      expect(events.any((e) => e['event'] == 'push.registered'), true);
    });

    test('handleForegroundMessage stores and emits', () {
      plugin.handleForegroundMessage({
        'messageId': 'msg_1',
        'title': 'Test',
        'body': 'Hello',
        'data': {'key': 'value'},
      });

      expect(events.any((e) => e['event'] == 'push.received'), true);
    });

    test('getDeliveredNotifications returns stored messages', () async {
      plugin.handleForegroundMessage({'title': 'A', 'body': 'B'});
      plugin.handleForegroundMessage({'title': 'C', 'body': 'D'});

      final r = await plugin.onCall('getDeliveredNotifications', {});
      expect(r['count'], 2);
    });

    test('removeAllDeliveredNotifications clears', () async {
      plugin.handleForegroundMessage({'title': 'A', 'body': 'B'});
      await plugin.onCall('removeAllDeliveredNotifications', {});

      final r = await plugin.onCall('getDeliveredNotifications', {});
      expect(r['count'], 0);
    });
  });
}
