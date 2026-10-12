import 'package:url_launcher/url_launcher.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class PhoneDialerPlugin extends Plugin {
  @override
  String get name => 'phoneDialer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Phone dialer and call plugin';

  @override
  List<String> get supportedMethods => [
        'dial',
        'directCall',
        'canDial',
        'sendSms',
        'sendEmail',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'dial':
        return _dial(args);
      case 'directCall':
        return _directCall(args);
      case 'canDial':
        return _canDial(args);
      case 'sendSms':
        return _sendSms(args);
      case 'sendEmail':
        return _sendEmail(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'supportedSchemes': ['tel', 'sms', 'smsto', 'mailto'],
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _dial(Map<String, dynamic> args) async {
    final number = args['number'] as String;
    final cleanNumber = _cleanPhoneNumber(number);
    final uri = Uri.parse('tel:$cleanNumber');

    final launched = await launchUrl(uri);

    return {
      'opened': launched,
      'number': cleanNumber,
      'mode': 'dialer',
    };
  }

  Future<Map<String, dynamic>> _directCall(Map<String, dynamic> args) async {
    final number = args['number'] as String;
    final cleanNumber = _cleanPhoneNumber(number);
    final uri = Uri.parse('tel:$cleanNumber');

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    return {
      'opened': launched,
      'number': cleanNumber,
      'mode': 'direct',
    };
  }

  Future<Map<String, dynamic>> _canDial(Map<String, dynamic> args) async {
    final number = args['number'] as String;
    final cleanNumber = _cleanPhoneNumber(number);
    final uri = Uri.parse('tel:$cleanNumber');

    final can = await canLaunchUrl(uri);

    return {
      'canDial': can,
      'number': cleanNumber,
    };
  }

  Future<Map<String, dynamic>> _sendSms(Map<String, dynamic> args) async {
    final number = args['number'] as String;
    final body = args['body'] as String? ?? '';
    final cleanNumber = _cleanPhoneNumber(number);

    final uri = Uri.parse('sms:$cleanNumber?body=${Uri.encodeComponent(body)}');
    final launched = await launchUrl(uri);

    return {
      'opened': launched,
      'number': cleanNumber,
      'type': 'sms',
    };
  }

  Future<Map<String, dynamic>> _sendEmail(Map<String, dynamic> args) async {
    final to = args['to'] as String;
    final subject = args['subject'] as String? ?? '';
    final body = args['body'] as String? ?? '';
    final cc = args['cc'] as String?;
    final bcc = args['bcc'] as String?;

    final params = <String, String>{};
    if (subject.isNotEmpty) params['subject'] = subject;
    if (body.isNotEmpty) params['body'] = body;
    if (cc != null && cc.isNotEmpty) params['cc'] = cc;
    if (bcc != null && bcc.isNotEmpty) params['bcc'] = bcc;

    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: params.isNotEmpty ? params : null,
    );

    final launched = await launchUrl(uri);

    return {
      'opened': launched,
      'to': to,
      'type': 'email',
    };
  }

  String _cleanPhoneNumber(String number) {
    return number.replaceAll(RegExp(r'[^\d+*#]'), '');
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'dial':
      case 'directCall':
      case 'canDial':
        final number = args['number'];
        if (number is! String || number.isEmpty) {
          return ValidationResult.invalid('number is required');
        }
        return ValidationResult.valid();

      case 'sendSms':
        final number = args['number'];
        if (number is! String || number.isEmpty) {
          return ValidationResult.invalid('number is required');
        }
        return ValidationResult.valid();

      case 'sendEmail':
        final to = args['to'];
        if (to is! String || to.isEmpty) {
          return ValidationResult.invalid('to (email) is required');
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
