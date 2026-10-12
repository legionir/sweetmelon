import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/firebase_remote_config/lib/firebase_remote_config_plugin.dart';

/// Exercises every [FirebaseRemoteConfigPlugin] method in a Firebase-less
/// test environment: the remote config instance stays null, so getters fall
/// back to defaults and remote operations degrade to safe results.
void main() {
  group('FirebaseRemoteConfigPlugin graceful degradation', () {
    late FirebaseRemoteConfigPlugin plugin;

    setUp(() async {
      plugin = FirebaseRemoteConfigPlugin();
      await plugin.initialize();
    });

    test('getInfo reports an uninitialized state', () async {
      final result = await plugin.onCall('getInfo', {});

      expect(result['name'], 'firebaseRemoteConfig');
      expect(result['initialized'], false);
      expect(result['lastFetchStatus'], isNull);
    });

    test('initialize reports the effective settings', () async {
      final result = await plugin.onCall('initialize', {
        'minimumFetchIntervalMs': 1000,
        'fetchTimeoutMs': 500,
        'defaults': {'welcome': 'hi'},
      });

      expect(result, {
        'initialized': true,
        'minimumFetchIntervalMs': 1000,
        'fetchTimeoutMs': 500,
      });
    });

    test('fetchAndActivate reports no update', () async {
      final result = await plugin.onCall('fetchAndActivate', {});

      expect(result, {'fetched': true, 'activated': true, 'updated': false});
    });

    test('fetch and activate degrade gracefully', () async {
      expect(await plugin.onCall('fetch', {}), {'fetched': true});
      expect(await plugin.onCall('activate', {}), {'activated': false});
    });

    test('typed getters fall back to empty defaults', () async {
      expect(
        await plugin.onCall('getString', {'key': 'title'}),
        {'key': 'title', 'value': ''},
      );
      expect(
        await plugin.onCall('getInt', {'key': 'count'}),
        {'key': 'count', 'value': 0},
      );
      expect(
        await plugin.onCall('getDouble', {'key': 'ratio'}),
        {'key': 'ratio', 'value': 0.0},
      );
      expect(
        await plugin.onCall('getBool', {'key': 'flag'}),
        {'key': 'flag', 'value': false},
      );
    });

    test('getJson decodes the empty default payload', () async {
      final result = await plugin.onCall('getJson', {'key': 'config'});

      expect(result['key'], 'config');
      expect(result['value'], isEmpty);
    });

    test('getAll reports an empty value map', () async {
      final result = await plugin.onCall('getAll', {});

      expect(result, {'values': {}, 'count': 0});
    });

    test('setDefaults and setConfigSettings report applied values', () async {
      final defaults = await plugin.onCall(
        'setDefaults',
        {
          'defaults': {'a': 1, 'b': 'two'},
        },
      );
      expect(defaults, {'set': true, 'count': 2});

      final settings = await plugin.onCall('setConfigSettings', {});
      expect(settings, {
        'set': true,
        'fetchTimeoutMs': 60000,
        'minimumFetchIntervalMs': 3600000,
      });
    });

    test('fetch metadata getters report unknown state', () async {
      final time = await plugin.onCall('getLastFetchTime', {});
      expect(time, {'timestamp': null, 'ms': null});

      final status = await plugin.onCall('getLastFetchStatus', {});
      expect(status, {'status': 'unknown'});
    });

    test('unknown methods throw UnsupportedError', () async {
      await expectLater(plugin.onCall('sync', {}), throwsUnsupportedError);
    });

    test('validateArgs requires keys and map defaults', () async {
      final noKey = await plugin.validateArgs('getString', {});
      expect(noKey.isValid, false);

      final withKey = await plugin.validateArgs('getInt', {'key': 'count'});
      expect(withKey.isValid, true);

      final badDefaults = await plugin.validateArgs(
        'setDefaults',
        {'defaults': 'not-a-map'},
      );
      expect(badDefaults.isValid, false);

      final goodDefaults = await plugin.validateArgs(
        'setDefaults',
        {
          'defaults': {'a': 1},
        },
      );
      expect(goodDefaults.isValid, true);
    });
  });
}
