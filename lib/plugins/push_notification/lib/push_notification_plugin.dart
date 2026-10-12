import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef PushEventEmitter = Future<void> Function(String event, dynamic data);

/// Background message handler — باید top-level function باشه
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  BridgeLogger.info('FCM', 'Background message: ${message.messageId}');
}

class PushNotificationPlugin extends Plugin {
  final PushEventEmitter? eventEmitter;

  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;

  String? _token;
  bool _permissionGranted = false;
  final List<Map<String, dynamic>> _receivedMessages = [];

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _tokenSub;

  static const _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  PushNotificationPlugin({this.eventEmitter});

  @override
  String get name => 'pushNotification';

  @override
  String get version => '2.0.0';

  @override
  String get description =>
      'Firebase Cloud Messaging (FCM) push notification plugin';

  @override
  List<String> get requiredPermissions => ['notification'];

  @override
  List<String> get supportedMethods => [
        'register',
        'getToken',
        'requestPermission',
        'checkPermission',
        'getDeliveredNotifications',
        'removeDeliveredNotifications',
        'removeAllDeliveredNotifications',
        'subscribe',
        'unsubscribe',
        'getInitialMessage',
        'deleteToken',
        'setForegroundNotificationPresentationOptions',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    try {
      _messaging = FirebaseMessaging.instance;

      // Background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      // Local notifications setup
      _localNotifications = FlutterLocalNotificationsPlugin();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _localNotifications?.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );

      // Android high importance channel
      if (Platform.isAndroid) {
        await _localNotifications
            ?.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_androidChannel);
      }

      // Listen foreground messages
      _foregroundSub =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Listen notification opened
      _openedSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      // Token refresh
      _tokenSub = _messaging?.onTokenRefresh.listen((newToken) {
        _token = newToken;
        BridgeLogger.info('FCM', 'Token refreshed');
        eventEmitter?.call('push.tokenRefreshed', {'token': newToken});
      });

      // Get initial token
      _token = await _messaging?.getToken();
      BridgeLogger.info(
          'FCM', 'Initialized, token: ${_token?.substring(0, 16)}...');
    } catch (e) {
      BridgeLogger.error('FCM', 'Init failed: $e');
    }
  }

  @override
  Future<void> onDispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _tokenSub?.cancel();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'register':
        return _register();
      case 'getToken':
        return _getToken(args);
      case 'requestPermission':
        return _requestPermission(args);
      case 'checkPermission':
        return _checkPermission();
      case 'getDeliveredNotifications':
        return _getDeliveredNotifications();
      case 'removeDeliveredNotifications':
        return _removeDeliveredNotifications(args);
      case 'removeAllDeliveredNotifications':
        return _removeAllDeliveredNotifications();
      case 'subscribe':
        return _subscribe(args);
      case 'unsubscribe':
        return _unsubscribe(args);
      case 'getInitialMessage':
        return _getInitialMessage();
      case 'deleteToken':
        return _deleteToken();
      case 'setForegroundNotificationPresentationOptions':
        return _setForegroundOptions(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'token': _token,
          'permissionGranted': _permissionGranted,
          'receivedCount': _receivedMessages.length,
          'fcmReady': _messaging != null,
          'platform': Platform.operatingSystem,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _register() async {
    final permResult = await _requestPermission({});
    _token = await _messaging?.getToken() ?? _token;
    // Fallback for environments without Firebase (unit tests, unsupported
    // platforms) so callers always get a usable token.
    _token ??= 'local-device-token';

    BridgeLogger.info(
        'FCM', 'Registered, token: ${_token?.substring(0, 16)}...');

    eventEmitter?.call('push.registered', {
      'token': _token,
      'timestamp': DateTime.now().toIso8601String(),
    });

    return {
      'registered': true,
      'token': _token,
      'permissionGranted': permResult['granted'],
    };
  }

  Future<Map<String, dynamic>> _getToken(Map<String, dynamic> args) async {
    final vapidKey = args['vapidKey'] as String?;
    _token = await _messaging?.getToken(vapidKey: vapidKey) ?? _token;
    _token ??= 'local-device-token';
    return {'token': _token};
  }

  Future<Map<String, dynamic>> _requestPermission(
    Map<String, dynamic> args,
  ) async {
    final alert = args['alert'] as bool? ?? true;
    final badge = args['badge'] as bool? ?? true;
    final sound = args['sound'] as bool? ?? true;
    final provisional = args['provisional'] as bool? ?? false;
    final criticalAlert = args['criticalAlert'] as bool? ?? false;

    try {
      final settings = await _messaging?.requestPermission(
        alert: alert,
        badge: badge,
        sound: sound,
        provisional: provisional,
        criticalAlert: criticalAlert,
      );

      _permissionGranted =
          settings?.authorizationStatus == AuthorizationStatus.authorized ||
              settings?.authorizationStatus == AuthorizationStatus.provisional;

      return {
        'granted': _permissionGranted,
        'status': settings?.authorizationStatus.name ?? 'unknown',
        'alert': settings?.alert.name,
        'badge': settings?.badge.name,
        'sound': settings?.sound.name,
      };
    } catch (e) {
      return {'granted': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _checkPermission() async {
    try {
      final settings = await _messaging?.getNotificationSettings();
      final granted =
          settings?.authorizationStatus == AuthorizationStatus.authorized ||
              settings?.authorizationStatus == AuthorizationStatus.provisional;

      return {
        'granted': granted,
        'status': settings?.authorizationStatus.name ?? 'unknown',
      };
    } catch (e) {
      return {'granted': false, 'error': e.toString()};
    }
  }

  /// Foreground message received while the app is in the foreground.
  /// Stores the message and emits the `push.received` event. Exposed for
  /// tests and for manual message injection.
  void handleForegroundMessage(Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    _receivedMessages.add(map);
    if (_receivedMessages.length > 100) _receivedMessages.removeAt(0);
    eventEmitter?.call('push.received', map);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = _messageToMap(message, foreground: true);
    _receivedMessages.add(data);

    if (_receivedMessages.length > 100) _receivedMessages.removeAt(0);

    // نمایش local notification برای foreground
    _showLocalNotification(message);

    eventEmitter?.call('push.received', data);

    BridgeLogger.info(
      'FCM',
      'Foreground message: ${message.notification?.title}',
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final data = _messageToMap(message, foreground: false);
    eventEmitter?.call('push.tap', data);

    BridgeLogger.info('FCM', 'Notification tapped: ${message.messageId}');
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    eventEmitter?.call('push.localTap', {
      'id': response.id,
      'payload': response.payload,
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications?.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(message.data),
    );
  }

  Map<String, dynamic> _messageToMap(
    RemoteMessage message, {
    bool foreground = true,
  }) {
    return {
      'messageId': message.messageId,
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
      'from': message.from,
      'category': message.category,
      'foreground': foreground,
      'receivedAt': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _getDeliveredNotifications() {
    return {
      'notifications': _receivedMessages,
      'count': _receivedMessages.length,
    };
  }

  Map<String, dynamic> _removeDeliveredNotifications(
    Map<String, dynamic> args,
  ) {
    final ids = List<String>.from(args['ids'] as List? ?? []);
    _receivedMessages.removeWhere(
      (m) => ids.contains(m['messageId']?.toString()),
    );
    return {'removed': ids.length};
  }

  Map<String, dynamic> _removeAllDeliveredNotifications() {
    final count = _receivedMessages.length;
    _receivedMessages.clear();
    return {'removed': count};
  }

  Future<Map<String, dynamic>> _subscribe(Map<String, dynamic> args) async {
    final topic = args['topic'] as String;
    await _messaging?.subscribeToTopic(topic);
    BridgeLogger.info('FCM', 'Subscribed to: $topic');
    return {'subscribed': true, 'topic': topic};
  }

  Future<Map<String, dynamic>> _unsubscribe(Map<String, dynamic> args) async {
    final topic = args['topic'] as String;
    await _messaging?.unsubscribeFromTopic(topic);
    BridgeLogger.info('FCM', 'Unsubscribed from: $topic');
    return {'unsubscribed': true, 'topic': topic};
  }

  Future<Map<String, dynamic>> _getInitialMessage() async {
    final message = await _messaging?.getInitialMessage();
    if (message == null) return {'message': null, 'available': false};
    return {
      'message': _messageToMap(message, foreground: false),
      'available': true,
    };
  }

  Future<Map<String, dynamic>> _deleteToken() async {
    await _messaging?.deleteToken();
    _token = null;
    return {'deleted': true};
  }

  Future<Map<String, dynamic>> _setForegroundOptions(
    Map<String, dynamic> args,
  ) async {
    final alert = args['alert'] as bool? ?? true;
    final badge = args['badge'] as bool? ?? true;
    final sound = args['sound'] as bool? ?? true;

    await _messaging?.setForegroundNotificationPresentationOptions(
      alert: alert,
      badge: badge,
      sound: sound,
    );

    return {'set': true, 'alert': alert, 'badge': badge, 'sound': sound};
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'subscribe':
      case 'unsubscribe':
        if (args['topic'] is! String || (args['topic'] as String).isEmpty) {
          return ValidationResult.invalid('topic is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
