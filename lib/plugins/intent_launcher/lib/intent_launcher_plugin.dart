import 'package:url_launcher/url_launcher.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class IntentLauncherPlugin extends Plugin {
  @override
  String get name => 'intentLauncher';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Launch Android intents and system screens';

  @override
  List<String> get supportedMethods => [
        'launch',
        'launchUrl',
        'isAppInstalled',
        'getInfo',
      ];

  static const Map<String, String> _knownIntents = {
    'settings': 'android.settings.SETTINGS',
    'wifi': 'android.settings.WIFI_SETTINGS',
    'bluetooth': 'android.settings.BLUETOOTH_SETTINGS',
    'location': 'android.settings.LOCATION_SOURCE_SETTINGS',
    'nfc': 'android.settings.NFC_SETTINGS',
    'airplane': 'android.settings.AIRPLANE_MODE_SETTINGS',
    'battery': 'android.settings.BATTERY_SAVER_SETTINGS',
    'display': 'android.settings.DISPLAY_SETTINGS',
    'sound': 'android.settings.SOUND_SETTINGS',
    'date': 'android.settings.DATE_SETTINGS',
    'apps': 'android.settings.APPLICATION_SETTINGS',
    'developer': 'android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
    'accessibility': 'android.settings.ACCESSIBILITY_SETTINGS',
    'security': 'android.settings.SECURITY_SETTINGS',
    'privacy': 'android.settings.PRIVACY_SETTINGS',
    'storage': 'android.settings.INTERNAL_STORAGE_SETTINGS',
    'about': 'android.settings.DEVICE_INFO_SETTINGS',
    'vpn': 'android.settings.VPN_SETTINGS',
    'data_roaming': 'android.settings.DATA_ROAMING_SETTINGS',
    'notification': 'android.settings.APP_NOTIFICATION_SETTINGS',
    'language': 'android.settings.LOCALE_SETTINGS',
    'keyboard': 'android.settings.INPUT_METHOD_SETTINGS',
    'default_apps': 'android.settings.MANAGE_DEFAULT_APPS_SETTINGS',
    'hotspot': 'android.settings.TETHER_SETTINGS',
    'mobile_data': 'android.settings.DATA_USAGE_SETTINGS',
  };

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'launch':
        return _launch(args);
      case 'launchUrl':
        return _launchUrl(args);
      case 'isAppInstalled':
        return _isAppInstalled(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'knownIntents': _knownIntents.keys.toList(),
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _launch(Map<String, dynamic> args) async {
    final intentName = args['intent'] as String;
    final action = _knownIntents[intentName] ?? intentName;

    try {
      final uri = Uri.parse('intent://#Intent;action=$action;end');
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);

      return {
        'launched': launched,
        'intent': intentName,
        'action': action,
      };
    } catch (e) {
      BridgeLogger.error('IntentLauncher', 'Launch failed: $e');
      return {'launched': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _launchUrl(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    final mode = args['mode'] as String? ?? 'external';

    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: mode == 'inApp'
            ? LaunchMode.inAppWebView
            : LaunchMode.externalApplication,
      );

      return {'launched': launched, 'url': url};
    } catch (e) {
      return {'launched': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _isAppInstalled(
      Map<String, dynamic> args) async {
    final packageName = args['packageName'] as String;

    try {
      final uri = Uri.parse('market://details?id=$packageName');
      final canOpen = await canLaunchUrl(uri);
      return {'installed': canOpen, 'packageName': packageName};
    } catch (e) {
      return {'installed': false, 'error': e.toString()};
    }
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'launch':
        if (args['intent'] is! String) {
          return ValidationResult.invalid('intent name is required');
        }
        return ValidationResult.valid();
      case 'launchUrl':
        if (args['url'] is! String) {
          return ValidationResult.invalid('url is required');
        }
        return ValidationResult.valid();
      case 'isAppInstalled':
        if (args['packageName'] is! String) {
          return ValidationResult.invalid('packageName is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
