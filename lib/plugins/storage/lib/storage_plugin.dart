import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class StoragePlugin extends Plugin {
  SharedPreferences? _prefs;
  static const String _keyPrefix = 'bridge_';

  @override
  String get name => 'storage';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Key-value storage plugin';

  @override
  bool get cacheable => true;

  @override
  Duration get defaultCacheTtl => const Duration(seconds: 30);

  @override
  List<String> get supportedMethods => [
        'get',
        'set',
        'remove',
        'clear',
        'keys',
        'has',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    _prefs = await SharedPreferences.getInstance();
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
      case 'clear':
        return _clear();
      case 'keys':
        return _keys();
      case 'has':
        return _has(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'prefix': _keyPrefix,
          'keysCount': _getBridgeKeys().length,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  dynamic _get(Map<String, dynamic> args) {
    final key = args['key'] as String;
    final raw = _prefs?.getString('$_keyPrefix$key');
    if (raw == null) return null;

    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  Future<bool> _set(Map<String, dynamic> args) async {
    final key = args['key'] as String;
    final value = args['value'];

    final encoded = jsonEncode(value);
    return await _prefs?.setString('$_keyPrefix$key', encoded) ?? false;
  }

  Future<bool> _remove(Map<String, dynamic> args) async {
    final key = args['key'] as String;
    return await _prefs?.remove('$_keyPrefix$key') ?? false;
  }

  Future<int> _clear() async {
    final keys = _getBridgeKeys();
    var count = 0;

    for (final key in keys) {
      final removed = await _prefs?.remove(key) ?? false;
      if (removed) count++;
    }

    return count;
  }

  Map<String, dynamic> _keys() {
    final keys =
        _getBridgeKeys().map((k) => k.substring(_keyPrefix.length)).toList();

    return {'keys': keys};
  }

  Map<String, dynamic> _has(Map<String, dynamic> args) {
    final key = args['key'] as String;
    return {'exists': _prefs?.containsKey('$_keyPrefix$key') ?? false};
  }

  List<String> _getBridgeKeys() {
    return _prefs?.getKeys().where((k) => k.startsWith(_keyPrefix)).toList() ??
        [];
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
        return _validateKeyRequired(args);
      case 'set':
        final keyResult = _validateKeyRequired(args);
        if (!keyResult.isValid) return keyResult;
        if (!args.containsKey('value')) {
          return ValidationResult.invalid('value is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }

  ValidationResult _validateKeyRequired(Map<String, dynamic> args) {
    final key = args['key'];
    if (key is! String || key.isEmpty) {
      return ValidationResult.invalid(
        'key is required and must be a non-empty string',
      );
    }
    return ValidationResult.valid();
  }
}
