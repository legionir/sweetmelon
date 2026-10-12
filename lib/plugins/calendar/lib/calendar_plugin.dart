import 'dart:async';

import 'package:device_calendar/device_calendar.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class CalendarPlugin extends Plugin {
  final DeviceCalendarPlugin _calendar = DeviceCalendarPlugin();

  @override
  String get name => 'calendar';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Device calendar read/write plugin';

  @override
  List<String> get supportedMethods => [
        'getCalendars',
        'getEvents',
        'createEvent',
        'deleteEvent',
        'hasPermission',
        'requestPermission',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getCalendars':
        return _getCalendars();
      case 'getEvents':
        return _getEvents(args);
      case 'createEvent':
        return _createEvent(args);
      case 'deleteEvent':
        return _deleteEvent(args);
      case 'hasPermission':
        return _hasPermission();
      case 'requestPermission':
        return _requestPermission();
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _hasPermission() async {
    final result = await _calendar.hasPermissions();
    return {
      'granted': result.data ?? false,
      'isSuccess': result.isSuccess,
    };
  }

  Future<Map<String, dynamic>> _requestPermission() async {
    final result = await _calendar.requestPermissions();
    return {
      'granted': result.data ?? false,
      'isSuccess': result.isSuccess,
    };
  }

  Future<Map<String, dynamic>> _getCalendars() async {
    final permResult = await _calendar.hasPermissions();
    if (permResult.data != true) {
      await _calendar.requestPermissions();
    }

    final result = await _calendar.retrieveCalendars();

    if (!result.isSuccess || result.data == null) {
      return {'calendars': <dynamic>[], 'error': result.errors.toString()};
    }

    final calendars = result.data!
        .map((c) => {
              'id': c.id,
              'name': c.name,
              'accountName': c.accountName,
              'accountType': c.accountType,
              'isReadOnly': c.isReadOnly,
              'color': c.color,
            })
        .toList();

    return {'calendars': calendars, 'count': calendars.length};
  }

  Future<Map<String, dynamic>> _getEvents(Map<String, dynamic> args) async {
    final calendarId = args['calendarId'] as String;
    final startMs = (args['startMs'] as num?)?.toInt();
    final endMs = (args['endMs'] as num?)?.toInt();
    final daysAhead = (args['daysAhead'] as num?)?.toInt() ?? 30;

    final start = startMs != null
        ? DateTime.fromMillisecondsSinceEpoch(startMs)
        : DateTime.now();
    final end = endMs != null
        ? DateTime.fromMillisecondsSinceEpoch(endMs)
        : DateTime.now().add(Duration(days: daysAhead));

    final params = RetrieveEventsParams(startDate: start, endDate: end);
    final result = await _calendar.retrieveEvents(calendarId, params);

    if (!result.isSuccess || result.data == null) {
      return {'events': <dynamic>[], 'error': result.errors.toString()};
    }

    final events = result.data!.map((e) => _eventToMap(e)).toList();

    return {'events': events, 'count': events.length};
  }

  Future<Map<String, dynamic>> _createEvent(Map<String, dynamic> args) async {
    final calendarId = args['calendarId'] as String;
    final title = args['title'] as String;
    final description = args['description'] as String? ?? '';
    final startMs = (args['startMs'] as num).toInt();
    final endMs = (args['endMs'] as num).toInt();
    final location = args['location'] as String?;
    final allDay = args['allDay'] as bool? ?? false;

    final event = Event(calendarId);
    event.title = title;
    event.description = description;
    event.start = TZDateTime.fromMillisecondsSinceEpoch(
      local,
      startMs,
    );
    event.end = TZDateTime.fromMillisecondsSinceEpoch(
      local,
      endMs,
    );
    event.location = location;
    event.allDay = allDay;

    final result = await _calendar.createOrUpdateEvent(event);

    if (!result!.isSuccess) {
      return {'created': false, 'error': result.errors.toString()};
    }

    BridgeLogger.info('Calendar', 'Event created: $title');

    return {
      'created': true,
      'eventId': result.data,
      'title': title,
    };
  }

  Future<Map<String, dynamic>> _deleteEvent(Map<String, dynamic> args) async {
    final calendarId = args['calendarId'] as String;
    final eventId = args['eventId'] as String;

    final result = await _calendar.deleteEvent(calendarId, eventId);

    if (!result.isSuccess) {
      return {'deleted': false, 'error': result.errors.toString()};
    }

    return {'deleted': true, 'eventId': eventId};
  }

  Map<String, dynamic> _eventToMap(Event event) {
    return {
      'eventId': event.eventId,
      'calendarId': event.calendarId,
      'title': event.title,
      'description': event.description,
      'start': event.start?.millisecondsSinceEpoch,
      'end': event.end?.millisecondsSinceEpoch,
      'startIso': event.start?.toIso8601String(),
      'endIso': event.end?.toIso8601String(),
      'location': event.location,
      'allDay': event.allDay,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'getEvents':
        if (args['calendarId'] is! String) {
          return ValidationResult.invalid('calendarId is required');
        }
        return ValidationResult.valid();

      case 'createEvent':
        for (final f in ['calendarId', 'title']) {
          if (args[f] is! String || (args[f] as String).isEmpty) {
            return ValidationResult.invalid('$f is required');
          }
        }
        for (final f in ['startMs', 'endMs']) {
          if (args[f] is! num) {
            return ValidationResult.invalid('$f (timestamp) is required');
          }
        }
        return ValidationResult.valid();

      case 'deleteEvent':
        for (final f in ['calendarId', 'eventId']) {
          if (args[f] is! String) {
            return ValidationResult.invalid('$f is required');
          }
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
