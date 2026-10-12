import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef NotificationEventEmitter = Future<void> Function(
  String event,
  dynamic data,
);

class NotificationPlugin extends Plugin {
  final NotificationEventEmitter? eventEmitter;
  late final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;

  final Map<int, Map<String, dynamic>> _activeNotifications = {};

  NotificationPlugin({this.eventEmitter});

  @override
  String get name => 'notification';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Local notification plugin';

  @override
  List<String> get supportedMethods => [
        'show',
        'cancel',
        'cancelAll',
        'getActive',
        'getPending',
        'createChannel',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    _notifications = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    _initialized = await _notifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onNotificationTap,
        ) ??
        false;

    BridgeLogger.info(
      'Notification',
      'Plugin initialized: $_initialized',
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    BridgeLogger.info(
      'Notification',
      'Notification tapped: ${response.id} payload=${response.payload}',
    );

    if (eventEmitter != null) {
      eventEmitter!(
        'notification.tap',
        {
          'id': response.id,
          'actionId': response.actionId,
          'payload': response.payload,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'show':
        return _show(args);
      case 'cancel':
        return _cancel(args);
      case 'cancelAll':
        return _cancelAll();
      case 'getActive':
        return _getActive();
      case 'getPending':
        return _getPending();
      case 'createChannel':
        return _createChannel(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'initialized': _initialized,
          'platform': Platform.operatingSystem,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _show(Map<String, dynamic> args) async {
    final id = (args['id'] as num?)?.toInt() ?? Random().nextInt(100000);
    final title = args['title'] as String? ?? '';
    final body = args['body'] as String? ?? '';
    final channelId = args['channelId'] as String? ?? 'default';
    final channelName = args['channelName'] as String? ?? 'Default';
    final payload = args['payload'] as String?;
    final importance =
        _parseImportance(args['importance'] as String? ?? 'high');
    final priority = _parsePriority(args['priority'] as String? ?? 'high');
    final ongoing = args['ongoing'] as bool? ?? false;
    final autoCancel = args['autoCancel'] as bool? ?? true;
    final silent = args['silent'] as bool? ?? false;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: args['channelDescription'] as String?,
      importance: importance,
      priority: priority,
      ongoing: ongoing,
      autoCancel: autoCancel,
      playSound: !silent,
      enableVibration: !silent,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);

    _activeNotifications[id] = {
      'id': id,
      'title': title,
      'body': body,
      'channelId': channelId,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    };

    return {'id': id, 'shown': true};
  }

  Future<Map<String, dynamic>> _cancel(Map<String, dynamic> args) async {
    final id = (args['id'] as num).toInt();
    await _notifications.cancel(id);
    _activeNotifications.remove(id);
    return {'id': id, 'cancelled': true};
  }

  Future<Map<String, dynamic>> _cancelAll() async {
    await _notifications.cancelAll();
    final count = _activeNotifications.length;
    _activeNotifications.clear();
    return {'cancelled': count};
  }

  Future<Map<String, dynamic>> _getActive() async {
    if (Platform.isAndroid) {
      final active = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.getActiveNotifications();

      if (active != null) {
        return {
          'count': active.length,
          'notifications': active.map((n) {
            return {
              'id': n.id,
              'channelId': n.channelId,
              'title': n.title,
              'body': n.body,
            };
          }).toList(),
        };
      }
    }

    return {
      'count': _activeNotifications.length,
      'notifications': _activeNotifications.values.toList(),
    };
  }

  Future<Map<String, dynamic>> _getPending() async {
    final pending = await _notifications.pendingNotificationRequests();
    return {
      'count': pending.length,
      'notifications': pending.map((n) {
        return {
          'id': n.id,
          'title': n.title,
          'body': n.body,
          'payload': n.payload,
        };
      }).toList(),
    };
  }

  Future<Map<String, dynamic>> _createChannel(
    Map<String, dynamic> args,
  ) async {
    if (!Platform.isAndroid) {
      return {'created': false, 'reason': 'not_android'};
    }

    final channelId = args['channelId'] as String;
    final channelName = args['channelName'] as String;
    final description = args['description'] as String?;
    final importance =
        _parseImportance(args['importance'] as String? ?? 'high');

    final channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: description ?? '',
      importance: importance,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    return {'created': true, 'channelId': channelId};
  }

  Importance _parseImportance(String value) {
    switch (value) {
      case 'none':
        return Importance.none;
      case 'min':
        return Importance.min;
      case 'low':
        return Importance.low;
      case 'default':
        return Importance.defaultImportance;
      case 'high':
        return Importance.high;
      case 'max':
        return Importance.max;
      default:
        return Importance.high;
    }
  }

  Priority _parsePriority(String value) {
    switch (value) {
      case 'min':
        return Priority.min;
      case 'low':
        return Priority.low;
      case 'default':
        return Priority.defaultPriority;
      case 'high':
        return Priority.high;
      case 'max':
        return Priority.max;
      default:
        return Priority.high;
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'show':
        final title = args['title'];
        if (title != null && title is! String) {
          return ValidationResult.invalid('title must be a string');
        }
        return ValidationResult.valid();

      case 'cancel':
        final id = args['id'];
        if (id is! num) {
          return ValidationResult.invalid(
              'id is required and must be a number');
        }
        return ValidationResult.valid();

      case 'createChannel':
        final channelId = args['channelId'];
        final channelName = args['channelName'];
        if (channelId is! String || channelId.isEmpty) {
          return ValidationResult.invalid('channelId is required');
        }
        if (channelName is! String || channelName.isEmpty) {
          return ValidationResult.invalid('channelName is required');
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
