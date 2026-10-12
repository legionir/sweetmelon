import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class ToastPlugin extends Plugin {
  @override
  String get name => 'toast';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Native toast notification plugin';

  @override
  List<String> get supportedMethods => [
        'show',
        'getInfo',
      ];

  BuildContext? get _context => AppContext().context;

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'show':
        return _show(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _show(Map<String, dynamic> args) async {
    final text = args['text'] as String;
    final durationStr = args['duration'] as String? ?? 'short';
    final position = args['position'] as String? ?? 'bottom';
    final backgroundColor = args['backgroundColor'] as String?;
    final textColor = args['textColor'] as String?;

    final context = _context;
    if (context == null) {
      return {'shown': false, 'reason': 'no_context'};
    }

    final duration = durationStr == 'long'
        ? const Duration(seconds: 4)
        : const Duration(seconds: 2);

    final snackBar = SnackBar(
      content: Text(
        text,
        style: TextStyle(
          color: _parseColor(textColor) ?? Colors.white,
        ),
      ),
      duration: duration,
      backgroundColor: _parseColor(backgroundColor) ?? const Color(0xFF323232),
      behavior: SnackBarBehavior.floating,
      margin: position == 'top'
          ? EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 150,
              left: 16,
              right: 16,
            )
          : const EdgeInsets.only(
              bottom: 16,
              left: 16,
              right: 16,
            ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);

    return {'shown': true, 'duration': durationStr};
  }

  Color? _parseColor(String? value) {
    if (value == null) return null;
    var hex = value.replaceAll('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      final intColor = int.tryParse(hex, radix: 16);
      if (intColor != null) return Color(intColor);
    }
    return null;
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'show') {
      final text = args['text'];
      if (text is! String || text.isEmpty) {
        return ValidationResult.invalid('text is required');
      }
    }
    return ValidationResult.valid();
  }
}
