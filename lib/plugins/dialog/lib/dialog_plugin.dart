import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:sweetmelon/plugins/qr_scanner/lib/qr_scanner_plugin.dart';

class DialogPlugin extends Plugin {
  @override
  String get name => 'dialog';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Native dialog windows: alert, confirm, prompt';

  @override
  List<String> get supportedMethods => [
        'alert',
        'confirm',
        'prompt',
        'getInfo',
      ];

  BuildContext? get _context => QrScannerPlugin.navigatorKey?.currentContext;

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'alert':
        return _alert(args);
      case 'confirm':
        return _confirm(args);
      case 'prompt':
        return _prompt(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _alert(Map<String, dynamic> args) async {
    final title = args['title'] as String? ?? '';
    final message = args['message'] as String? ?? '';
    final buttonTitle = args['buttonTitle'] as String? ?? 'OK';

    final context = _context;
    if (context == null) {
      return {'dismissed': false, 'reason': 'no_context'};
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: title.isNotEmpty ? Text(title) : null,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(buttonTitle),
          ),
        ],
      ),
    );

    return {'dismissed': true};
  }

  Future<Map<String, dynamic>> _confirm(Map<String, dynamic> args) async {
    final title = args['title'] as String? ?? '';
    final message = args['message'] as String? ?? '';
    final okButtonTitle = args['okButtonTitle'] as String? ?? 'OK';
    final cancelButtonTitle = args['cancelButtonTitle'] as String? ?? 'Cancel';

    final context = _context;
    if (context == null) {
      return {'confirmed': false, 'reason': 'no_context'};
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: title.isNotEmpty ? Text(title) : null,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelButtonTitle),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(okButtonTitle),
          ),
        ],
      ),
    );

    return {'confirmed': result ?? false};
  }

  Future<Map<String, dynamic>> _prompt(Map<String, dynamic> args) async {
    final title = args['title'] as String? ?? '';
    final message = args['message'] as String? ?? '';
    final placeholder = args['placeholder'] as String? ?? '';
    final defaultValue = args['defaultValue'] as String? ?? '';
    final okButtonTitle = args['okButtonTitle'] as String? ?? 'OK';
    final cancelButtonTitle = args['cancelButtonTitle'] as String? ?? 'Cancel';
    final inputType = args['inputType'] as String? ?? 'text';
    final maxLength = (args['maxLength'] as num?)?.toInt();

    final context = _context;
    if (context == null) {
      return {'cancelled': true, 'value': null, 'reason': 'no_context'};
    }

    final controller = TextEditingController(text: defaultValue);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: title.isNotEmpty ? Text(title) : null,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(message),
              ),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: maxLength,
              keyboardType: _parseInputType(inputType),
              obscureText: inputType == 'password',
              decoration: InputDecoration(
                hintText: placeholder,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(cancelButtonTitle),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(okButtonTitle),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null) {
      return {'cancelled': true, 'value': null};
    }

    return {'cancelled': false, 'value': result};
  }

  TextInputType _parseInputType(String type) {
    switch (type) {
      case 'number':
        return TextInputType.number;
      case 'phone':
        return TextInputType.phone;
      case 'email':
        return TextInputType.emailAddress;
      case 'url':
        return TextInputType.url;
      case 'multiline':
        return TextInputType.multiline;
      case 'password':
      case 'text':
      default:
        return TextInputType.text;
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'alert':
      case 'confirm':
        final message = args['message'];
        if (message is! String || message.isEmpty) {
          return ValidationResult.invalid('message is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
