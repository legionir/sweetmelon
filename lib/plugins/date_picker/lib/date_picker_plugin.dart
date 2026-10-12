import 'package:flutter/material.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:sweetmelon/plugins/qr_scanner/lib/qr_scanner_plugin.dart';

class DatePickerPlugin extends Plugin {
  @override
  String get name => 'datePicker';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Native date and time picker dialogs';

  @override
  List<String> get supportedMethods => [
        'pickDate',
        'pickTime',
        'pickDateTime',
        'pickDateRange',
        'getInfo',
      ];

  BuildContext? get _context => QrScannerPlugin.navigatorKey?.currentContext;

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'pickDate':
        return _pickDate(args);
      case 'pickTime':
        return _pickTime(args);
      case 'pickDateTime':
        return _pickDateTime(args);
      case 'pickDateRange':
        return _pickDateRange(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _pickDate(Map<String, dynamic> args) async {
    final context = _context;
    if (context == null) {
      return {'picked': false, 'reason': 'no_context'};
    }

    final initialMs = (args['initialDateMs'] as num?)?.toInt();
    final firstMs = (args['firstDateMs'] as num?)?.toInt();
    final lastMs = (args['lastDateMs'] as num?)?.toInt();
    final title = args['title'] as String?;

    final now = DateTime.now();
    final initialDate = initialMs != null
        ? DateTime.fromMillisecondsSinceEpoch(initialMs)
        : now;
    final firstDate = firstMs != null
        ? DateTime.fromMillisecondsSinceEpoch(firstMs)
        : DateTime(now.year - 100);
    final lastDate = lastMs != null
        ? DateTime.fromMillisecondsSinceEpoch(lastMs)
        : DateTime(now.year + 100);

    final result = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: title,
    );

    if (result == null) {
      return {'picked': false, 'reason': 'cancelled'};
    }

    return {
      'picked': true,
      'year': result.year,
      'month': result.month,
      'day': result.day,
      'dateMs': result.millisecondsSinceEpoch,
      'dateIso': result.toIso8601String(),
      'formatted':
          '${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}',
    };
  }

  Future<Map<String, dynamic>> _pickTime(Map<String, dynamic> args) async {
    final context = _context;
    if (context == null) {
      return {'picked': false, 'reason': 'no_context'};
    }

    final initialHour =
        (args['initialHour'] as num?)?.toInt() ?? TimeOfDay.now().hour;
    final initialMinute =
        (args['initialMinute'] as num?)?.toInt() ?? TimeOfDay.now().minute;
    final use24h = args['use24h'] as bool? ?? true;
    final title = args['title'] as String?;

    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: use24h
          ? (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(alwaysUse24HourFormat: true),
                child: child!,
              )
          : null,
      helpText: title,
    );

    if (result == null) {
      return {'picked': false, 'reason': 'cancelled'};
    }

    return {
      'picked': true,
      'hour': result.hour,
      'minute': result.minute,
      'formatted':
          '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}',
    };
  }

  Future<Map<String, dynamic>> _pickDateTime(Map<String, dynamic> args) async {
    final dateResult = await _pickDate(args);
    if (dateResult['picked'] != true) return dateResult;

    final timeResult = await _pickTime(args);
    if (timeResult['picked'] != true) return timeResult;

    final date = DateTime(
      dateResult['year'] as int,
      dateResult['month'] as int,
      dateResult['day'] as int,
      timeResult['hour'] as int,
      timeResult['minute'] as int,
    );

    return {
      'picked': true,
      'year': date.year,
      'month': date.month,
      'day': date.day,
      'hour': date.hour,
      'minute': date.minute,
      'dateTimeMs': date.millisecondsSinceEpoch,
      'dateTimeIso': date.toIso8601String(),
      'formatted':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
    };
  }

  Future<Map<String, dynamic>> _pickDateRange(Map<String, dynamic> args) async {
    final context = _context;
    if (context == null) {
      return {'picked': false, 'reason': 'no_context'};
    }

    final now = DateTime.now();
    final firstMs = (args['firstDateMs'] as num?)?.toInt();
    final lastMs = (args['lastDateMs'] as num?)?.toInt();

    final result = await showDateRangePicker(
      context: context,
      firstDate: firstMs != null
          ? DateTime.fromMillisecondsSinceEpoch(firstMs)
          : DateTime(now.year - 10),
      lastDate: lastMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastMs)
          : DateTime(now.year + 10),
    );

    if (result == null) {
      return {'picked': false, 'reason': 'cancelled'};
    }

    return {
      'picked': true,
      'start': {
        'dateMs': result.start.millisecondsSinceEpoch,
        'dateIso': result.start.toIso8601String(),
      },
      'end': {
        'dateMs': result.end.millisecondsSinceEpoch,
        'dateIso': result.end.toIso8601String(),
      },
      'durationDays': result.duration.inDays,
    };
  }
}
