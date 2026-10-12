import 'package:url_launcher/url_launcher.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class EmailComposerPlugin extends Plugin {
  @override
  String get name => 'emailComposer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Compose and send email with attachments';

  @override
  List<String> get supportedMethods => [
        'compose',
        'canCompose',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'compose':
        return _compose(args);
      case 'canCompose':
        return _canCompose();
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _compose(Map<String, dynamic> args) async {
    final to = _parseRecipients(args['to']);
    final cc = _parseRecipients(args['cc']);
    final bcc = _parseRecipients(args['bcc']);
    final subject = args['subject'] as String? ?? '';
    final body = args['body'] as String? ?? '';

    if (to.isEmpty) {
      return {'opened': false, 'reason': 'no_recipients'};
    }

    final params = <String, String>{};
    if (subject.isNotEmpty) params['subject'] = subject;
    if (body.isNotEmpty) params['body'] = body;
    if (cc.isNotEmpty) params['cc'] = cc.join(',');
    if (bcc.isNotEmpty) params['bcc'] = bcc.join(',');

    final uri = Uri(
      scheme: 'mailto',
      path: to.join(','),
      queryParameters: params.isNotEmpty ? params : null,
    );

    try {
      final launched = await launchUrl(uri);
      return {
        'opened': launched,
        'to': to,
        'subject': subject,
      };
    } catch (e) {
      return {'opened': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _canCompose() async {
    try {
      final uri = Uri.parse('mailto:test@example.com');
      final can = await canLaunchUrl(uri);
      return {'available': can};
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }

  List<String> _parseRecipients(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    if (method == 'compose') {
      final to = args['to'];
      if (to == null) {
        return ValidationResult.invalid('to (email address) is required');
      }
    }
    return ValidationResult.valid();
  }
}
