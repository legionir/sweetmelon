import 'dart:async';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef AlarmEventEmitter = Future<void> Function(String event, dynamic data);

class AlarmPlugin extends Plugin {
  final AlarmEventEmitter? eventEmitter;
  final Map<String, Timer> _alarms = {};
  final Map<String, Map<String, dynamic>> _alarmData = {};

  AlarmPlugin({this.eventEmitter});

  @override
  String get name => 'alarm';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Timer-based alarm plugin';

  @override
  List<String> get supportedMethods => [
        'set',
        'cancel',
        'cancelAll',
        'getAlarm',
        'getAllAlarms',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    for (final timer in _alarms.values) {
      timer.cancel();
    }
    _alarms.clear();
    _alarmData.clear();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'set':
        return _set(args);
      case 'cancel':
        return _cancel(args);
      case 'cancelAll':
        return _cancelAll();
      case 'getAlarm':
        return _getAlarm(args);
      case 'getAllAlarms':
        return _getAllAlarms();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'activeAlarms': _alarms.length,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _set(Map<String, dynamic> args) {
    final alarmId = args['alarmId'] as String? ??
        'alarm_${DateTime.now().millisecondsSinceEpoch}';
    final delayMs = (args['delayMs'] as num?)?.toInt();
    final atMs = (args['atMs'] as num?)?.toInt();
    final title = args['title'] as String? ?? 'Alarm';
    final body = args['body'] as String? ?? '';
    final repeating = args['repeating'] as bool? ?? false;
    final intervalMs = (args['intervalMs'] as num?)?.toInt();
    final payload = args['payload'];

    // Cancel existing
    _alarms[alarmId]?.cancel();

    Duration delay;
    if (delayMs != null) {
      delay = Duration(milliseconds: delayMs);
    } else if (atMs != null) {
      final target = DateTime.fromMillisecondsSinceEpoch(atMs);
      delay = target.difference(DateTime.now());
      if (delay.isNegative) delay = Duration.zero;
    } else {
      return {'set': false, 'reason': 'delayMs or atMs is required'};
    }

    final data = {
      'alarmId': alarmId,
      'title': title,
      'body': body,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
      'fireAt': DateTime.now().add(delay).toIso8601String(),
      'repeating': repeating,
    };

    _alarmData[alarmId] = data;

    if (repeating && intervalMs != null) {
      // اول بار بعد از delay، بعد هر intervalMs تکرار
      _alarms[alarmId] = Timer(delay, () {
        _fireAlarm(alarmId);

        _alarms[alarmId] = Timer.periodic(
          Duration(milliseconds: intervalMs),
          (_) => _fireAlarm(alarmId),
        );
      });
    } else {
      _alarms[alarmId] = Timer(delay, () => _fireAlarm(alarmId));
    }

    BridgeLogger.info('Alarm', 'Set: $alarmId (${delay.inSeconds}s)');

    return {
      'set': true,
      'alarmId': alarmId,
      'fireAt': DateTime.now().add(delay).toIso8601String(),
      'delayMs': delay.inMilliseconds,
    };
  }

  void _fireAlarm(String alarmId) {
    final data = _alarmData[alarmId];
    if (data == null) return;

    BridgeLogger.info('Alarm', 'Fired: $alarmId');

    eventEmitter?.call('alarm.fired', {
      ...data,
      'firedAt': DateTime.now().toIso8601String(),
    });

    // اگه repeating نبود، حذف کن
    if (data['repeating'] != true) {
      _alarms.remove(alarmId);
      _alarmData.remove(alarmId);
    }
  }

  Map<String, dynamic> _cancel(Map<String, dynamic> args) {
    final alarmId = args['alarmId'] as String;
    _alarms[alarmId]?.cancel();
    _alarms.remove(alarmId);
    _alarmData.remove(alarmId);
    return {'cancelled': true, 'alarmId': alarmId};
  }

  Map<String, dynamic> _cancelAll() {
    final count = _alarms.length;
    for (final timer in _alarms.values) {
      timer.cancel();
    }
    _alarms.clear();
    _alarmData.clear();
    return {'cancelled': count};
  }

  Map<String, dynamic> _getAlarm(Map<String, dynamic> args) {
    final alarmId = args['alarmId'] as String;
    final data = _alarmData[alarmId];
    if (data == null) {
      return {'found': false, 'alarmId': alarmId};
    }
    return {'found': true, ...data, 'active': _alarms.containsKey(alarmId)};
  }

  Map<String, dynamic> _getAllAlarms() {
    return {
      'alarms': _alarmData.values
          .map((d) => {
                ...d,
                'active': _alarms.containsKey(d['alarmId']),
              })
          .toList(),
      'count': _alarmData.length,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'set':
        if (args['delayMs'] == null && args['atMs'] == null) {
          return ValidationResult.invalid('delayMs or atMs is required');
        }
        return ValidationResult.valid();
      case 'cancel':
      case 'getAlarm':
        if (args['alarmId'] is! String) {
          return ValidationResult.invalid('alarmId is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
