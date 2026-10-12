import 'dart:io';

import 'package:url_launcher/url_launcher.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class NativeSettingsPlugin extends Plugin {
  @override
  String get name => 'nativeSettings';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Open native system settings screens';

  @override
  List<String> get supportedMethods => [
        'open',
        'openApp',
        'openWifi',
        'openBluetooth',
        'openLocation',
        'openNotification',
        'openBattery',
        'openDisplay',
        'openSound',
        'openSecurity',
        'openDate',
        'openAccessibility',
        'openStorage',
        'openDeveloper',
        'openAbout',
        'getAvailableSettings',
        'getInfo',
      ];

  static const Map<String, String> _androidSettingsMap = {
    'app': 'android.settings.APPLICATION_DETAILS_SETTINGS',
    'wifi': 'android.settings.WIFI_SETTINGS',
    'bluetooth': 'android.settings.BLUETOOTH_SETTINGS',
    'location': 'android.settings.LOCATION_SOURCE_SETTINGS',
    'notification': 'android.settings.APP_NOTIFICATION_SETTINGS',
    'battery': 'android.settings.BATTERY_SAVER_SETTINGS',
    'display': 'android.settings.DISPLAY_SETTINGS',
    'sound': 'android.settings.SOUND_SETTINGS',
    'security': 'android.settings.SECURITY_SETTINGS',
    'date': 'android.settings.DATE_SETTINGS',
    'accessibility': 'android.settings.ACCESSIBILITY_SETTINGS',
    'storage': 'android.settings.INTERNAL_STORAGE_SETTINGS',
    'developer': 'android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
    'about': 'android.settings.DEVICE_INFO_SETTINGS',
    'nfc': 'android.settings.NFC_SETTINGS',
    'airplane': 'android.settings.AIRPLANE_MODE_SETTINGS',
    'apn': 'android.settings.APN_SETTINGS',
    'data_usage': 'android.settings.DATA_USAGE_SETTINGS',
    'vpn': 'android.settings.VPN_SETTINGS',
    'input_method': 'android.settings.INPUT_METHOD_SETTINGS',
    'locale': 'android.settings.LOCALE_SETTINGS',
    'privacy': 'android.settings.PRIVACY_SETTINGS',
    'biometric': 'android.settings.BIOMETRIC_ENROLL',
    'default_apps': 'android.settings.MANAGE_DEFAULT_APPS_SETTINGS',
  };

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'open':
        return _openSetting(args['setting'] as String);
      case 'openApp':
        return _openSetting('app');
      case 'openWifi':
        return _openSetting('wifi');
      case 'openBluetooth':
        return _openSetting('bluetooth');
      case 'openLocation':
        return _openSetting('location');
      case 'openNotification':
        return _openSetting('notification');
      case 'openBattery':
        return _openSetting('battery');
      case 'openDisplay':
        return _openSetting('display');
      case 'openSound':
        return _openSetting('sound');
      case 'openSecurity':
        return _openSetting('security');
      case 'openDate':
        return _openSetting('date');
      case 'openAccessibility':
        return _openSetting('accessibility');
      case 'openStorage':
        return _openSetting('storage');
      case 'openDeveloper':
        return _openSetting('developer');
      case 'openAbout':
        return _openSetting('about');
      case 'getAvailableSettings':
        return {'settings': _androidSettingsMap.keys.toList()};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'platform': Platform.operatingSystem,
          'availableSettings': _androidSettingsMap.keys.toList(),
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _openSetting(String setting) async {
    if (!Platform.isAndroid) {
      return {'opened': false, 'reason': 'android_only'};
    }

    final action = _androidSettingsMap[setting];
    if (action == null) {
      return {
        'opened': false,
        'reason': 'unknown_setting',
        'setting': setting,
        'availableSettings': _androidSettingsMap.keys.toList(),
      };
    }

    try {
      // استفاده از intent
      final intent = Uri.parse(
        'intent://#Intent;action=$action;end',
      );

      final launched = await launchUrl(
        intent,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // fallback: باز کردن تنظیمات عمومی
        await launchUrl(
          Uri.parse('app-settings:'),
          mode: LaunchMode.externalApplication,
        );
      }

      BridgeLogger.info('NativeSettings', 'Opened: $setting');

      return {'opened': true, 'setting': setting};
    } catch (e) {
      BridgeLogger.error('NativeSettings', 'Open failed: $e');

      // Fallback: باز کردن تنظیمات اپ
      try {
        await launchUrl(
          Uri.parse('app-settings:'),
          mode: LaunchMode.externalApplication,
        );
        return {'opened': true, 'setting': 'app', 'fallback': true};
      } catch (_) {}

      return {'opened': false, 'error': e.toString()};
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'open') {
      final setting = args['setting'];
      if (setting is! String || setting.isEmpty) {
        return ValidationResult.invalid('setting name is required');
      }
    }
    return ValidationResult.valid();
  }
}
