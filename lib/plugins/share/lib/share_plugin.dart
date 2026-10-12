import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class ShareBridgePlugin extends Plugin {
  @override
  String get name => 'share';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Native share plugin';

  @override
  List<String> get supportedMethods => [
        'shareText',
        'shareFiles',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'shareText':
        return _shareText(args);
      case 'shareFiles':
        return _shareFiles(args);
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _shareText(Map<String, dynamic> args) async {
    final text = args['text'] as String;
    final subject = args['subject'] as String?;

    await Share.share(text, subject: subject);

    return {
      'shared': true,
      'type': 'text',
    };
  }

  Future<Map<String, dynamic>> _shareFiles(Map<String, dynamic> args) async {
    final rawPaths = List<String>.from(args['paths'] as List);
    final subject = args['subject'] as String?;
    final text = args['text'] as String?;

    final files = <XFile>[];

    for (final path in rawPaths) {
      final file = File(path);
      if (!await file.exists()) {
        throw FileSystemException('File not found', path);
      }
      files.add(XFile(file.path));
    }

    await Share.shareXFiles(
      files,
      subject: subject,
      text: text,
    );

    return {
      'shared': true,
      'type': 'files',
      'count': files.length,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'shareText':
        final text = args['text'];
        if (text is! String || text.isEmpty) {
          return ValidationResult.invalid(
            'text is required and must be a non-empty string',
          );
        }
        return ValidationResult.valid();

      case 'shareFiles':
        final paths = args['paths'];
        if (paths is! List || paths.isEmpty) {
          return ValidationResult.invalid(
            'paths is required and must be a non-empty list',
          );
        }
        if (paths.any((e) => e is! String || e.isEmpty)) {
          return ValidationResult.invalid(
            'all paths must be non-empty strings',
          );
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
