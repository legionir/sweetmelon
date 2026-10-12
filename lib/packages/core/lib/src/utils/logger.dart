import 'dart:async';

import 'package:flutter/foundation.dart';

enum LogLevel {
  debug(0, 'DEBUG'),
  info(1, 'INFO'),
  warn(2, 'WARN'),
  error(3, 'ERROR');

  final int value;
  final String label;
  const LogLevel(this.value, this.label);
}

class LogEntry {
  final LogLevel level;
  final String tag;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? extra;

  const LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    required this.timestamp,
    this.extra,
  });

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'tag': tag,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        if (extra != null) 'extra': extra,
      };

  @override
  String toString() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';

    return '[${level.label}] [$tag] $time - $message';
  }
}

class BridgeLogger {
  static LogLevel _minLevel = kReleaseMode ? LogLevel.warn : LogLevel.debug;
  static final List<LogEntry> _history = [];
  static StreamController<LogEntry>? _controller;
  static final List<LogSink> _sinks = [
    if (kDebugMode) DebugConsoleSink(),
  ];

  static StreamController<LogEntry> get _streamController {
    _controller ??= StreamController<LogEntry>.broadcast();
    return _controller!;
  }

  static Stream<LogEntry> get stream => _streamController.stream;
  static List<LogEntry> get history => List.unmodifiable(_history);

  static void setMinLevel(LogLevel level) => _minLevel = level;

  static void addSink(LogSink sink) {
    if (!_sinks.contains(sink)) {
      _sinks.add(sink);
    }
  }

  static void removeSink(LogSink sink) => _sinks.remove(sink);

  static void debug(String tag, String message, [Map<String, dynamic>? extra]) {
    _log(LogLevel.debug, tag, message, extra);
  }

  static void info(String tag, String message, [Map<String, dynamic>? extra]) {
    _log(LogLevel.info, tag, message, extra);
  }

  static void warn(String tag, String message, [Map<String, dynamic>? extra]) {
    _log(LogLevel.warn, tag, message, extra);
  }

  static void error(String tag, String message, [Map<String, dynamic>? extra]) {
    _log(LogLevel.error, tag, message, extra);
  }

  static void _log(
    LogLevel level,
    String tag,
    String message,
    Map<String, dynamic>? extra,
  ) {
    if (level.value < _minLevel.value) return;

    final entry = LogEntry(
      level: level,
      tag: tag,
      message: message,
      timestamp: DateTime.now(),
      extra: extra,
    );

    _history.add(entry);
    if (_history.length > 1000) _history.removeAt(0);

    if (_controller != null && !_controller!.isClosed) {
      _controller!.add(entry);
    }

    for (final sink in _sinks) {
      try {
        sink.write(entry);
      } catch (_) {
        // Sink error should never crash the app
      }
    }
  }

  static void clear() => _history.clear();

  static void dispose() {
    _controller?.close();
    _controller = null;
  }
}

abstract class LogSink {
  void write(LogEntry entry);
}

/// استفاده از debugPrint به جای print
class DebugConsoleSink implements LogSink {
  @override
  void write(LogEntry entry) {
    debugPrint(entry.toString());
  }
}

class MemorySink implements LogSink {
  final List<LogEntry> entries = [];
  final int maxEntries;

  MemorySink({this.maxEntries = 500});

  @override
  void write(LogEntry entry) {
    entries.add(entry);
    if (entries.length > maxEntries) entries.removeAt(0);
  }
}
