import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class FirebaseAnalyticsPlugin extends Plugin {
  FirebaseAnalytics? _analytics;
  bool _enabled = true;

  @override
  String get name => 'firebaseAnalytics';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Firebase Analytics integration';

  @override
  List<String> get supportedMethods => [
        'logEvent',
        'setUserId',
        'setUserProperty',
        'setCurrentScreen',
        'logLogin',
        'logSignUp',
        'logSearch',
        'logSelectContent',
        'logShare',
        'logPurchase',
        'logViewItem',
        'logViewItemList',
        'logAddToCart',
        'logBeginCheckout',
        'logTutorialBegin',
        'logTutorialComplete',
        'logLevelStart',
        'logLevelEnd',
        'setAnalyticsCollectionEnabled',
        'resetAnalyticsData',
        'getAppInstanceId',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      BridgeLogger.info('FirebaseAnalytics', 'Initialized');
    } catch (e) {
      BridgeLogger.error('FirebaseAnalytics', 'Init failed: $e');
    }
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'logEvent':
        return _logEvent(args);
      case 'setUserId':
        return _setUserId(args);
      case 'setUserProperty':
        return _setUserProperty(args);
      case 'setCurrentScreen':
        return _setCurrentScreen(args);
      case 'logLogin':
        return _logLogin(args);
      case 'logSignUp':
        return _logSignUp(args);
      case 'logSearch':
        return _logSearch(args);
      case 'logSelectContent':
        return _logSelectContent(args);
      case 'logShare':
        return _logShare(args);
      case 'logPurchase':
        return _logPurchase(args);
      case 'logViewItem':
        return _logViewItem(args);
      case 'logViewItemList':
        return _logViewItemList(args);
      case 'logAddToCart':
        return _logAddToCart(args);
      case 'logBeginCheckout':
        return _logBeginCheckout(args);
      case 'logTutorialBegin':
        await _analytics?.logTutorialBegin();
        return {'logged': true};
      case 'logTutorialComplete':
        await _analytics?.logTutorialComplete();
        return {'logged': true};
      case 'logLevelStart':
        return _logLevelStart(args);
      case 'logLevelEnd':
        return _logLevelEnd(args);
      case 'setAnalyticsCollectionEnabled':
        return _setCollectionEnabled(args);
      case 'resetAnalyticsData':
        await _analytics?.resetAnalyticsData();
        return {'reset': true};
      case 'getAppInstanceId':
        final id = await _analytics?.appInstanceId;
        return {'appInstanceId': id};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'enabled': _enabled,
          'initialized': _analytics != null,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _logEvent(Map<String, dynamic> args) async {
    final eventName = args['name'] as String;
    final parameters = args['parameters'] as Map<String, dynamic>? ?? {};

    await _analytics?.logEvent(
      name: eventName,
      parameters: _sanitizeParameters(parameters),
    );

    BridgeLogger.debug('FirebaseAnalytics', 'Event: $eventName');
    return {'logged': true, 'event': eventName};
  }

  Future<Map<String, dynamic>> _setUserId(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    await _analytics?.setUserId(id: id);
    return {'set': true};
  }

  Future<Map<String, dynamic>> _setUserProperty(
    Map<String, dynamic> args,
  ) async {
    final name = args['name'] as String;
    final value = args['value'] as String?;
    await _analytics?.setUserProperty(name: name, value: value);
    return {'set': true, 'name': name};
  }

  Future<Map<String, dynamic>> _setCurrentScreen(
    Map<String, dynamic> args,
  ) async {
    final screenName = args['screenName'] as String;
    final screenClass = args['screenClass'] as String?;
    await _analytics?.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
    return {'set': true, 'screenName': screenName};
  }

  Future<Map<String, dynamic>> _logLogin(Map<String, dynamic> args) async {
    await _analytics?.logLogin(
        loginMethod: args['method'] as String? ?? 'email');
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _logSignUp(Map<String, dynamic> args) async {
    await _analytics?.logSignUp(
        signUpMethod: args['method'] as String? ?? 'email');
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _logSearch(Map<String, dynamic> args) async {
    await _analytics?.logSearch(searchTerm: args['searchTerm'] as String);
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _logSelectContent(
    Map<String, dynamic> args,
  ) async {
    await _analytics?.logSelectContent(
      contentType: args['contentType'] as String,
      itemId: args['itemId'] as String,
    );
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _logShare(Map<String, dynamic> args) async {
    await _analytics?.logShare(
      contentType: args['contentType'] as String,
      itemId: args['itemId'] as String,
      method: args['method'] as String? ?? 'unknown',
    );
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _logPurchase(Map<String, dynamic> args) async {
    await _analytics?.logPurchase(
      currency: args['currency'] as String? ?? 'USD',
      value: (args['value'] as num?)?.toDouble() ?? 0,
      transactionId: args['transactionId'] as String?,
      items: _parseItems(args['items']),
    );
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _logViewItem(Map<String, dynamic> args) async {
    await _analytics?.logViewItem(
      currency: args['currency'] as String? ?? 'USD',
      value: (args['value'] as num?)?.toDouble() ?? 0,
      items: _parseItems(args['items']),
    );
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _logViewItemList(
    Map<String, dynamic> args,
  ) async {
    await _analytics?.logViewItemList(
      itemListId: args['itemListId'] as String?,
      itemListName: args['itemListName'] as String?,
      items: _parseItems(args['items']),
    );
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _logAddToCart(
    Map<String, dynamic> args,
  ) async {
    await _analytics?.logAddToCart(
      currency: args['currency'] as String? ?? 'USD',
      value: (args['value'] as num?)?.toDouble() ?? 0,
      items: _parseItems(args['items']),
    );
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _logBeginCheckout(
    Map<String, dynamic> args,
  ) async {
    await _analytics?.logBeginCheckout(
      currency: args['currency'] as String? ?? 'USD',
      value: (args['value'] as num?)?.toDouble() ?? 0,
      items: _parseItems(args['items']),
    );
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _logLevelStart(
    Map<String, dynamic> args,
  ) async {
    await _analytics?.logLevelStart(
        levelName: args['levelName'] as String? ?? '');
    return {'logged': true};
  }

  Future<Map<String, dynamic>> _logLevelEnd(
    Map<String, dynamic> args,
  ) async {
    await _analytics?.logLevelEnd(
      levelName: args['levelName'] as String? ?? '',
      success: _toSuccessFlag(args['success']),
    );
    return {'logged': true};
  }

  /// نگاشت مقدار success ورودی پل به عدد موردانتظار SDK.
  ///
  /// هم مقدار بولی واقعی (مثلاً `false`) و هم رشتهٔ «'true'/'false'» پذیرفته
  /// می‌شود؛ در نبود مقدار، پیش‌فرض موفق است.
  int _toSuccessFlag(dynamic raw) {
    if (raw is bool) return raw ? 1 : 0;
    if (raw is String) return raw == 'true' ? 1 : 0;
    return 1;
  }

  Future<Map<String, dynamic>> _setCollectionEnabled(
    Map<String, dynamic> args,
  ) async {
    final enabled = args['enabled'] as bool? ?? true;
    await _analytics?.setAnalyticsCollectionEnabled(enabled);
    _enabled = enabled;
    return {'enabled': enabled};
  }

  Map<String, Object>? _sanitizeParameters(Map<String, dynamic> params) {
    if (params.isEmpty) return null;
    final result = <String, Object>{};
    params.forEach((key, value) {
      if (value is String) {
        result[key] = value;
      } else if (value is int) {
        result[key] = value;
      } else if (value is double) {
        result[key] = value;
      } else if (value is bool) {
        // SDK فقط string یا number را می‌پذیرد؛ ارسال مستقیم boolean باعث
        // AssertionError در مسیر فعال Firebase می‌شود.
        result[key] = value ? 'true' : 'false';
      } else {
        result[key] = value.toString();
      }
    });
    return result;
  }

  List<AnalyticsEventItem>? _parseItems(dynamic items) {
    if (items == null) return null;
    if (items is! List) return null;

    return items.map((item) {
      final m = item as Map<String, dynamic>;
      return AnalyticsEventItem(
        itemId: m['itemId'] as String?,
        itemName: m['itemName'] as String?,
        itemCategory: m['itemCategory'] as String?,
        price: (m['price'] as num?)?.toDouble(),
        quantity: (m['quantity'] as num?)?.toInt(),
        currency: m['currency'] as String?,
      );
    }).toList();
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'logEvent':
        if (args['name'] is! String || (args['name'] as String).isEmpty) {
          return ValidationResult.invalid('name is required');
        }
        return ValidationResult.valid();

      case 'setUserId':
        return ValidationResult.valid();

      case 'setUserProperty':
        if (args['name'] is! String || (args['name'] as String).isEmpty) {
          return ValidationResult.invalid('name is required');
        }
        return ValidationResult.valid();

      case 'setCurrentScreen':
        if (args['screenName'] is! String) {
          return ValidationResult.invalid('screenName is required');
        }
        return ValidationResult.valid();

      case 'logSearch':
        if (args['searchTerm'] is! String) {
          return ValidationResult.invalid('searchTerm is required');
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
