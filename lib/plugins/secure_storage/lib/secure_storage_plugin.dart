import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class SecureStoragePlugin extends Plugin {
  late final FlutterSecureStorage _storage;

  static const String _keyPrefix = 'sec_';

  @override
  String get name => 'secureStorage';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Encrypted key-value secure storage plugin';

  @override
  List<String> get supportedMethods => [
        'get',
        'set',
        'remove',
        'has',
        'keys',
        'clear',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'get':
        return _get(args);
      case 'set':
        return _set(args);
      case 'remove':
        return _remove(args);
      case 'has':
        return _has(args);
      case 'keys':
        return _keys();
      case 'clear':
        return _clear();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'encrypted': true,
          'prefix': _keyPrefix,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _get(Map<String, dynamic> args) async {
    final key = args['key'] as String;
    final raw = await _storage.read(key: '$_keyPrefix$key');

    if (raw == null) {
      return {'key': key, 'value': null, 'found': false};
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      decoded = raw;
    }

    return {'key': key, 'value': decoded, 'found': true};
  }

  Future<Map<String, dynamic>> _set(Map<String, dynamic> args) async {
    final key = args['key'] as String;
    final value = args['value'];

    final encoded = jsonEncode(value);
    await _storage.write(key: '$_keyPrefix$key', value: encoded);

    return {'key': key, 'written': true};
  }

  Future<Map<String, dynamic>> _remove(Map<String, dynamic> args) async {
    final key = args['key'] as String;
    await _storage.delete(key: '$_keyPrefix$key');
    return {'key': key, 'removed': true};
  }

  Future<Map<String, dynamic>> _has(Map<String, dynamic> args) async {
    final key = args['key'] as String;
    final value = await _storage.read(key: '$_keyPrefix$key');
    return {'key': key, 'exists': value != null};
  }

  Future<Map<String, dynamic>> _keys() async {
    final all = await _storage.readAll();
    final bridgeKeys = all.keys
        .where((k) => k.startsWith(_keyPrefix))
        .map((k) => k.substring(_keyPrefix.length))
        .toList();

    return {'keys': bridgeKeys, 'count': bridgeKeys.length};
  }

  Future<Map<String, dynamic>> _clear() async {
    final all = await _storage.readAll();
    int count = 0;

    for (final key in all.keys) {
      if (key.startsWith(_keyPrefix)) {
        await _storage.delete(key: key);
        count++;
      }
    }

    return {'cleared': count};
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'get':
      case 'remove':
      case 'has':
        return _validateKey(args);
      case 'set':
        final keyResult = _validateKey(args);
        if (!keyResult.isValid) return keyResult;
        if (!args.containsKey('value')) {
          return ValidationResult.invalid('value is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }

  ValidationResult _validateKey(Map<String, dynamic> args) {
    final key = args['key'];
    if (key is! String || key.isEmpty) {
      return ValidationResult.invalid(
        'key is required and must be a non-empty string',
      );
    }
    return ValidationResult.valid();
  }
}
