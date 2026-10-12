import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class ClipboardPlugin extends Plugin {
  @override
  String get name => 'clipboard';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Clipboard text plugin';

  @override
  List<String> get supportedMethods => [
        'readText',
        'writeText',
        'hasText',
        'clear',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'readText':
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        return {'text': data?.text};
      case 'writeText':
        final text = args['text'] as String;
        await Clipboard.setData(ClipboardData(text: text));
        return {'written': true};
      case 'hasText':
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        return {'hasText': (data?.text?.isNotEmpty ?? false)};
      case 'clear':
        await Clipboard.setData(const ClipboardData(text: ''));
        return {'cleared': true};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'writeText') {
      final text = args['text'];
      if (text is! String) {
        return ValidationResult.invalid(
          'text is required and must be a string',
        );
      }
    }
    return ValidationResult.valid();
  }
}
