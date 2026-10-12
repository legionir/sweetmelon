import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweetmelon/plugins/storage/lib/storage_plugin.dart';

void main() {
  group('StoragePlugin', () {
    late StoragePlugin plugin;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      plugin = StoragePlugin();
      await plugin.initialize();
    });

    test('set and get string value', () async {
      await plugin.onCall('set', {'key': 'name', 'value': 'Ali'});
      final result = await plugin.onCall('get', {'key': 'name'});

      expect(result, 'Ali');
    });

    test('set and get complex value', () async {
      final data = {
        'name': 'Ali',
        'age': 30,
        'tags': ['a', 'b']
      };
      await plugin.onCall('set', {'key': 'user', 'value': data});
      final result = await plugin.onCall('get', {'key': 'user'});

      expect(result['name'], 'Ali');
      expect(result['age'], 30);
      expect(result['tags'], ['a', 'b']);
    });

    test('get returns null for missing key', () async {
      final result = await plugin.onCall('get', {'key': 'nonexistent'});
      expect(result, isNull);
    });

    test('has returns correct value', () async {
      await plugin.onCall('set', {'key': 'exists', 'value': true});

      final r1 = await plugin.onCall('has', {'key': 'exists'});
      expect(r1['exists'], true);

      final r2 = await plugin.onCall('has', {'key': 'missing'});
      expect(r2['exists'], false);
    });

    test('remove deletes key', () async {
      await plugin.onCall('set', {'key': 'temp', 'value': 'data'});
      await plugin.onCall('remove', {'key': 'temp'});

      final result = await plugin.onCall('get', {'key': 'temp'});
      expect(result, isNull);
    });

    test('keys returns all bridge keys', () async {
      await plugin.onCall('set', {'key': 'a', 'value': 1});
      await plugin.onCall('set', {'key': 'b', 'value': 2});

      final result = await plugin.onCall('keys', {});

      expect(result['keys'], containsAll(['a', 'b']));
    });

    test('clear removes all bridge keys', () async {
      await plugin.onCall('set', {'key': 'x', 'value': 1});
      await plugin.onCall('set', {'key': 'y', 'value': 2});

      final count = await plugin.onCall('clear', {});
      expect(count, 2);

      final keys = await plugin.onCall('keys', {});
      expect((keys['keys'] as List).isEmpty, true);
    });

    test('validation rejects empty key', () async {
      final result = await plugin.validateArgs('get', {'key': ''});
      expect(result.isValid, false);
    });

    test('validation rejects missing key', () async {
      final result = await plugin.validateArgs('get', {});
      expect(result.isValid, false);
    });

    test('validation rejects set without value', () async {
      final result = await plugin.validateArgs('set', {'key': 'test'});
      expect(result.isValid, false);
    });
  });
}
