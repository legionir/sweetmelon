import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class AppIntegrityPlugin extends Plugin {
  static const _channel = MethodChannel('sweetmelon/app_integrity');

  @override
  String get name => 'appIntegrity';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'App integrity and attestation (Play Integrity API ready)';

  @override
  List<String> get supportedMethods => [
        'checkIntegrity',
        'isGenuineInstall',
        'getInstallSource',
        'getSigningInfo',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'checkIntegrity':
        return _checkIntegrity();
      case 'isGenuineInstall':
        return _isGenuineInstall();
      case 'getInstallSource':
        return _getInstallSource();
      case 'getSigningInfo':
        return _getSigningInfo();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'platform': Platform.operatingSystem,
          'playIntegrityReady': false,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _checkIntegrity() async {
    final install = await _isGenuineInstall();
    final source = await _getInstallSource();
    final signing = await _getSigningInfo();

    final isGenuine = install['genuine'] == true;
    final isPlayStore = source['source'] == 'com.android.vending';

    String verdict;
    if (isGenuine && isPlayStore) {
      verdict = 'trusted';
    } else if (isGenuine) {
      verdict = 'genuine';
    } else {
      verdict = 'untrusted';
    }

    return {
      'verdict': verdict,
      'genuine': isGenuine,
      'playStore': isPlayStore,
      'install': install,
      'source': source,
      'signing': signing,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _isGenuineInstall() async {
    try {
      final result = await _channel.invokeMethod('isGenuineInstall');
      return {'genuine': result ?? false};
    } catch (e) {
      // Fallback: بررسی installer package
      final source = await _getInstallSource();
      final genuine = source['source'] == 'com.android.vending' ||
          source['source'] == 'com.google.android.packageinstaller';

      return {'genuine': genuine, 'method': 'fallback'};
    }
  }

  Future<Map<String, dynamic>> _getInstallSource() async {
    try {
      final result = await _channel.invokeMethod('getInstallSource');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (_) {}

    return {
      'source': 'unknown',
      'initiating': null,
      'originating': null,
    };
  }

  Future<Map<String, dynamic>> _getSigningInfo() async {
    try {
      final result = await _channel.invokeMethod('getSigningInfo');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (_) {}

    return {
      'signed': true,
      'debugBuild': _isDebugMode(),
    };
  }

  bool _isDebugMode() {
    bool debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug;
  }
}
