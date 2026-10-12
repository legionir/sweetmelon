import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/firebase_analytics/lib/firebase_analytics_plugin.dart';

/// Exercises every [FirebaseAnalyticsPlugin] method in a Firebase-less test
/// environment: the analytics instance stays null, so all log calls must
/// degrade to no-op successes.
void main() {
  group('FirebaseAnalyticsPlugin graceful degradation', () {
    late FirebaseAnalyticsPlugin plugin;

    setUp(() async {
      plugin = FirebaseAnalyticsPlugin();
      await plugin.initialize();
    });

    test('getInfo reports uninitialized state', () async {
      final result = await plugin.onCall('getInfo', {});

      expect(result['name'], 'firebaseAnalytics');
      expect(result['initialized'], false);
      expect(result['enabled'], true);
    });

    test('logEvent sanitizes mixed parameter types', () async {
      final result = await plugin.onCall('logEvent', {
        'name': 'checkout',
        'parameters': {
          'label': 'summer',
          'count': 3,
          'price': 9.99,
          'active': true,
          'nested': {'a': 1},
        },
      });

      expect(result, {'logged': true, 'event': 'checkout'});
    });

    test('logEvent accepts missing parameters', () async {
      final result = await plugin.onCall('logEvent', {'name': 'ping'});

      expect(result, {'logged': true, 'event': 'ping'});
    });

    test('setUserId and setUserProperty succeed', () async {
      final id = await plugin.onCall('setUserId', {'id': 'user-1'});
      expect(id, {'set': true});

      final property = await plugin.onCall(
        'setUserProperty',
        {'name': 'plan', 'value': 'pro'},
      );
      expect(property, {'set': true, 'name': 'plan'});
    });

    test('setCurrentScreen logs a screen view', () async {
      final result = await plugin.onCall('setCurrentScreen', {
        'screenName': 'Home',
        'screenClass': 'HomeScreen',
      });

      expect(result, {'set': true, 'screenName': 'Home'});
    });

    test('login, signup and search events log', () async {
      expect(await plugin.onCall('logLogin', {'method': 'google'}),
          {'logged': true});
      expect(await plugin.onCall('logSignUp', {'method': 'email'}),
          {'logged': true});
      expect(await plugin.onCall('logSearch', {'searchTerm': 'shoes'}),
          {'logged': true});
    });

    test('content events log', () async {
      final select = await plugin.onCall('logSelectContent', {
        'contentType': 'product',
        'itemId': 'sku-1',
      });
      expect(select, {'logged': true});

      final share = await plugin.onCall('logShare', {
        'contentType': 'product',
        'itemId': 'sku-1',
        'method': 'telegram',
      });
      expect(share, {'logged': true});
    });

    test('commerce events parse item lists', () async {
      final items = [
        {
          'itemId': 'i-1',
          'itemName': 'Mug',
          'itemCategory': 'kitchen',
          'price': 4.5,
          'quantity': 2,
          'currency': 'USD',
        },
      ];

      final purchase = await plugin.onCall('logPurchase', {
        'currency': 'USD',
        'value': 9,
        'transactionId': 't-1',
        'items': items,
      });
      expect(purchase, {'logged': true});

      final viewItem = await plugin.onCall(
          'logViewItem', {'currency': 'USD', 'value': 4.5, 'items': items});
      expect(viewItem, {'logged': true});

      final viewList = await plugin.onCall('logViewItemList', {
        'itemListId': 'list-1',
        'itemListName': 'featured',
        'items': items,
      });
      expect(viewList, {'logged': true});

      final addToCart = await plugin.onCall(
          'logAddToCart', {'currency': 'USD', 'value': 4.5, 'items': items});
      expect(addToCart, {'logged': true});

      final beginCheckout = await plugin.onCall(
          'logBeginCheckout', {'currency': 'USD', 'value': 9, 'items': items});
      expect(beginCheckout, {'logged': true});
    });

    test('item parsing ignores non-list payloads', () async {
      final result = await plugin.onCall('logViewItem', {'items': 'oops'});

      expect(result, {'logged': true});
    });

    test('tutorial and level events log with success mapping', () async {
      expect(await plugin.onCall('logTutorialBegin', {}), {'logged': true});
      expect(
        await plugin.onCall('logTutorialComplete', {}),
        {'logged': true},
      );
      expect(await plugin.onCall('logLevelStart', {'levelName': 'l-1'}),
          {'logged': true});
      expect(
        await plugin
            .onCall('logLevelEnd', {'levelName': 'l-1', 'success': 'false'}),
        {'logged': true},
      );
    });

    test('collection flag toggles and is reported', () async {
      final disabled = await plugin.onCall(
        'setAnalyticsCollectionEnabled',
        {'enabled': false},
      );
      expect(disabled, {'enabled': false});
      expect((await plugin.onCall('getInfo', {}))['enabled'], false);

      final enabled = await plugin.onCall(
        'setAnalyticsCollectionEnabled',
        {'enabled': true},
      );
      expect(enabled, {'enabled': true});
    });

    test('resetAnalyticsData and getAppInstanceId succeed', () async {
      expect(await plugin.onCall('resetAnalyticsData', {}), {'reset': true});

      final id = await plugin.onCall('getAppInstanceId', {});
      expect(id, {'appInstanceId': null});
    });

    test('unknown methods throw UnsupportedError', () async {
      await expectLater(plugin.onCall('beacon', {}), throwsUnsupportedError);
    });

    test('validateArgs guards event, property, screen and search args',
        () async {
      final noName = await plugin.validateArgs('logEvent', {});
      expect(noName.isValid, false);

      final withName = await plugin.validateArgs('logEvent', {'name': 'ok'});
      expect(withName.isValid, true);

      final noProperty = await plugin.validateArgs('setUserProperty', {});
      expect(noProperty.isValid, false);

      final noScreen = await plugin.validateArgs('setCurrentScreen', {});
      expect(noScreen.isValid, false);

      final noSearch = await plugin.validateArgs('logSearch', {});
      expect(noSearch.isValid, false);

      final userId = await plugin.validateArgs('setUserId', {});
      expect(userId.isValid, true);
    });
  });
}
