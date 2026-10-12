import 'dart:async';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class CookieManagerPlugin extends Plugin {
  WebViewCookieManager? _cookieManager;
  bool _cookieManagerUnavailable = false;

  /// Lazily created: constructing [WebViewCookieManager] requires a
  /// WebViewPlatform implementation, which unit tests don't provide.
  WebViewCookieManager? get _cookies {
    if (_cookieManagerUnavailable) return null;
    try {
      return _cookieManager ??= WebViewCookieManager();
    } catch (_) {
      _cookieManagerUnavailable = true;
      return null;
    }
  }

  @override
  String get name => 'cookieManager';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'WebView cookie and session management plugin';

  @override
  List<String> get supportedMethods => [
        'setCookie',
        'clearCookies',
        'clearSession',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'setCookie':
        return _setCookie(args);
      case 'clearCookies':
        return _clearCookies();
      case 'clearSession':
        return _clearSession();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _setCookie(Map<String, dynamic> args) async {
    final domain = args['domain'] as String;
    final name = args['name'] as String;
    final value = args['value'] as String;
    final path = args['path'] as String? ?? '/';

    final cookies = _cookies;
    if (cookies == null) {
      return {
        'set': false,
        'error': 'cookie manager unavailable on this platform',
      };
    }

    try {
      await cookies.setCookie(
        WebViewCookie(
          name: name,
          value: value,
          domain: domain,
          path: path,
        ),
      );

      BridgeLogger.info(
        'CookieManager',
        'Cookie set: $name=$value for $domain',
      );

      return {
        'set': true,
        'name': name,
        'domain': domain,
      };
    } catch (e) {
      BridgeLogger.error('CookieManager', 'Failed to set cookie: $e');
      return {
        'set': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _clearCookies() async {
    final cookies = _cookies;
    if (cookies == null) {
      return {'cleared': false, 'error': 'cookie manager unavailable'};
    }

    try {
      final cleared = await cookies.clearCookies();

      BridgeLogger.info('CookieManager', 'Cookies cleared: $cleared');

      return {'cleared': cleared};
    } catch (e) {
      BridgeLogger.error('CookieManager', 'Failed to clear cookies: $e');
      return {'cleared': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _clearSession() async {
    final cookies = _cookies;
    if (cookies == null) {
      return {'cleared': false, 'error': 'cookie manager unavailable'};
    }

    try {
      final cleared = await cookies.clearCookies();

      BridgeLogger.info('CookieManager', 'Session cleared');

      return {'cleared': cleared};
    } catch (e) {
      return {'cleared': false, 'error': e.toString()};
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'setCookie') {
      for (final field in ['domain', 'name', 'value']) {
        final val = args[field];
        if (val is! String || val.isEmpty) {
          return ValidationResult.invalid('$field is required');
        }
      }
    }
    return ValidationResult.valid();
  }
}
