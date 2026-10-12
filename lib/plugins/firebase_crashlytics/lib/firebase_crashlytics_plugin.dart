import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class FirebaseCrashlyticsPlugin extends Plugin {
  FirebaseCrashlytics? _crashlytics;

  @override
  String get name => 'firebaseCrashlytics';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Firebase Crashlytics integration';

  @override
  List<String> get supportedMethods => [
        'recordError',
        'log',
        'setUserId',
        'setCustomKey',
        'setCustomKeys',
        'sendUnsentReports',
        'deleteUnsentReports',
        'setCrashlyticsCollectionEnabled',
        'checkForUnsentReports',
        'crash',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    try {
      _crashlytics = FirebaseCrashlytics.instance;

      // Flutter error handler
      FlutterError.onError = (details) {
        _crashlytics?.recordFlutterFatalError(details);
      };

      // Async error handler
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics?.recordError(error, stack, fatal: true);
        return true;
      };

      BridgeLogger.info('Crashlytics', 'Initialized');
    } catch (e) {
      BridgeLogger.error('Crashlytics', 'Init failed: $e');
    }
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'recordError':
        return _recordError(args);
      case 'log':
        return _log(args);
      case 'setUserId':
        return _setUserId(args);
      case 'setCustomKey':
        return _setCustomKey(args);
      case 'setCustomKeys':
        return _setCustomKeys(args);
      case 'sendUnsentReports':
        await _crashlytics?.sendUnsentReports();
        return {'sent': true};
      case 'deleteUnsentReports':
        await _crashlytics?.deleteUnsentReports();
        return {'deleted': true};
      case 'setCrashlyticsCollectionEnabled':
        return _setCollectionEnabled(args);
      case 'checkForUnsentReports':
        final has = await _crashlytics?.checkForUnsentReports() ?? false;
        return {'hasUnsentReports': has};
      case 'crash':
        if (!kReleaseMode) {
          _crashlytics?.crash();
          return {'crashed': true};
        }
        return {'crashed': false, 'reason': 'only_in_debug'};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'initialized': _crashlytics != null,
          'isCrashlyticsCollectionEnabled':
              _crashlytics?.isCrashlyticsCollectionEnabled ?? false,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _recordError(
    Map<String, dynamic> args,
  ) async {
    final message = args['message'] as String;
    final type = args['type'] as String? ?? 'Error';
    final isFatal = args['fatal'] as bool? ?? false;
    final customKeys = args['keys'] as Map<String, dynamic>? ?? {};

    // Set custom keys before recording
    for (final entry in customKeys.entries) {
      if (entry.value is String) {
        await _crashlytics?.setCustomKey(entry.key, entry.value as String);
      } else if (entry.value is int) {
        await _crashlytics?.setCustomKey(entry.key, entry.value as int);
      } else if (entry.value is double) {
        await _crashlytics?.setCustomKey(entry.key, entry.value as double);
      } else if (entry.value is bool) {
        await _crashlytics?.setCustomKey(entry.key, entry.value as bool);
      }
    }

    await _crashlytics?.recordError(
      Exception('$type: $message'),
      null,
      fatal: isFatal,
      reason: message,
    );

    BridgeLogger.info(
      'Crashlytics',
      'Error recorded: $type (fatal: $isFatal)',
    );

    return {'recorded': true, 'fatal': isFatal};
  }

  Future<Map<String, dynamic>> _log(Map<String, dynamic> args) async {
    final message = args['message'] as String;
    await _crashlytics?.log(message);
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _setUserId(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    await _crashlytics?.setUserIdentifier(id);
    return {'set': true};
  }

  Future<Map<String, dynamic>> _setCustomKey(
    Map<String, dynamic> args,
  ) async {
    final key = args['key'] as String;
    final value = args['value'];

    if (value is String) {
      await _crashlytics?.setCustomKey(key, value);
    } else if (value is int) {
      await _crashlytics?.setCustomKey(key, value);
    } else if (value is double) {
      await _crashlytics?.setCustomKey(key, value);
    } else if (value is bool) {
      await _crashlytics?.setCustomKey(key, value);
    } else {
      await _crashlytics?.setCustomKey(key, value.toString());
    }

    return {'set': true, 'key': key};
  }

  Future<Map<String, dynamic>> _setCustomKeys(
    Map<String, dynamic> args,
  ) async {
    final keys = args['keys'] as Map<String, dynamic>;
    for (final entry in keys.entries) {
      await _setCustomKey({'key': entry.key, 'value': entry.value});
    }
    return {'set': true, 'count': keys.length};
  }

  Future<Map<String, dynamic>> _setCollectionEnabled(
    Map<String, dynamic> args,
  ) async {
    final enabled = args['enabled'] as bool? ?? true;
    await _crashlytics?.setCrashlyticsCollectionEnabled(enabled);
    return {'enabled': enabled};
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'recordError':
        if (args['message'] is! String || (args['message'] as String).isEmpty) {
          return ValidationResult.invalid('message is required');
        }
        return ValidationResult.valid();
      case 'log':
        if (args['message'] is! String) {
          return ValidationResult.invalid('message is required');
        }
        return ValidationResult.valid();
      case 'setUserId':
        if (args['id'] is! String) {
          return ValidationResult.invalid('id is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
