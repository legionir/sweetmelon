import 'plugin_registry_data.dart';

/// Native requirements (Android permissions and features, iOS usage
/// descriptions) of the plugins that are not described in
/// [PluginRegistryData]. Together the two tables cover every plugin under
/// lib/plugins; a test fails when a plugin has no entry in either.
///
/// `sweetmelon sync` reads these tables to add and remove the entries in
/// AndroidManifest.xml and Info.plist for the enabled plugins. A plugin that
/// needs nothing has an explicit empty entry, so "no permissions" is a
/// decision and not an oversight.
///
/// Not covered: manifest components (intent filters, services, queries) and
/// Info.plist values that are not strings (for example UIBackgroundModes).
class PluginNativeRequirements {
  const PluginNativeRequirements({
    this.androidPermissions = const [],
    this.androidFeatures = const [],
    this.iosUsageDescriptions = const {},
  });

  final List<String> androidPermissions;
  final List<String> androidFeatures;
  final Map<String, String> iosUsageDescriptions;
}

class PluginNativeRequirementsData {
  /// Plugin directory name -> requirements.
  static const Map<String, PluginNativeRequirements> byPlugin = {
    'accessibility': PluginNativeRequirements(),
    'action_sheet': PluginNativeRequirements(),
    'alarm': PluginNativeRequirements(),
    'app_integrity': PluginNativeRequirements(),
    'app_update': PluginNativeRequirements(),
    'background_geolocation': PluginNativeRequirements(androidPermissions: [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.ACCESS_BACKGROUND_LOCATION'
    ], iosUsageDescriptions: {
      'NSLocationWhenInUseUsageDescription':
          'Location access while using the app',
      'NSLocationAlwaysAndWhenInUseUsageDescription':
          'Location access in the background',
      'NSLocationAlwaysUsageDescription': 'Location access in the background'
    }),
    'background_task': PluginNativeRequirements(),
    'badge': PluginNativeRequirements(),
    'cache_control': PluginNativeRequirements(),
    'calendar': PluginNativeRequirements(androidPermissions: [
      'android.permission.READ_CALENDAR',
      'android.permission.WRITE_CALENDAR'
    ], iosUsageDescriptions: {
      'NSCalendarsUsageDescription': 'Calendar access',
      'NSCalendarsFullAccessUsageDescription': 'Calendar access'
    }),
    'camera_preview': PluginNativeRequirements(androidPermissions: [
      'android.permission.CAMERA',
      'android.permission.RECORD_AUDIO'
    ], iosUsageDescriptions: {
      'NSCameraUsageDescription': 'Camera access',
      'NSMicrophoneUsageDescription': 'Microphone access for video recording'
    }),
    'cookie_manager': PluginNativeRequirements(),
    'date_picker': PluginNativeRequirements(),
    'dialog': PluginNativeRequirements(),
    'document_scanner': PluginNativeRequirements(androidPermissions: [
      'android.permission.CAMERA'
    ], iosUsageDescriptions: {
      'NSCameraUsageDescription': 'Camera access for scanning documents'
    }),
    'email_composer': PluginNativeRequirements(),
    'file_compressor': PluginNativeRequirements(),
    'file_opener': PluginNativeRequirements(),
    'file_picker': PluginNativeRequirements(iosUsageDescriptions: {
      'NSPhotoLibraryUsageDescription': 'Photo library access'
    }),
    'firebase_analytics': PluginNativeRequirements(),
    'firebase_auth': PluginNativeRequirements(),
    'firebase_crashlytics': PluginNativeRequirements(),
    'firebase_remote_config': PluginNativeRequirements(),
    'flashlight': PluginNativeRequirements(androidPermissions: [
      'android.permission.CAMERA'
    ], androidFeatures: [
      'android.hardware.camera.flash'
    ], iosUsageDescriptions: {
      'NSCameraUsageDescription': 'Camera access for the flashlight'
    }),
    'foreground_service': PluginNativeRequirements(androidPermissions: [
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.POST_NOTIFICATIONS'
    ]),
    'ftp_client': PluginNativeRequirements(iosUsageDescriptions: {
      'NSLocalNetworkUsageDescription':
          'Connects to devices on your local network'
    }),
    'ftp_server': PluginNativeRequirements(iosUsageDescriptions: {
      'NSLocalNetworkUsageDescription':
          'Connects to devices on your local network'
    }),
    'google_maps': PluginNativeRequirements(),
    'http_server': PluginNativeRequirements(iosUsageDescriptions: {
      'NSLocalNetworkUsageDescription':
          'Connects to devices on your local network'
    }),
    'in_app_purchase': PluginNativeRequirements(
        androidPermissions: ['com.android.vending.BILLING']),
    'in_app_review': PluginNativeRequirements(),
    'intent_launcher': PluginNativeRequirements(),
    'kiosk_mode': PluginNativeRequirements(),
    'live_updater': PluginNativeRequirements(),
    'loader_status': PluginNativeRequirements(),
    'media_manager': PluginNativeRequirements(iosUsageDescriptions: {
      'NSPhotoLibraryAddUsageDescription': 'Save media to your photo library',
      'NSPhotoLibraryUsageDescription': 'Photo library access'
    }),
    'native_market': PluginNativeRequirements(),
    'native_settings': PluginNativeRequirements(),
    'navigation_bar': PluginNativeRequirements(),
    'network_info': PluginNativeRequirements(),
    'oauth2': PluginNativeRequirements(),
    'pdf_plugin': PluginNativeRequirements(),
    'pedometer': PluginNativeRequirements(androidPermissions: [
      'android.permission.ACTIVITY_RECOGNITION'
    ], iosUsageDescriptions: {
      'NSMotionUsageDescription': 'Motion data access'
    }),
    'ping_dns': PluginNativeRequirements(iosUsageDescriptions: {
      'NSLocalNetworkUsageDescription':
          'Connects to devices on your local network'
    }),
    'privacy_screen': PluginNativeRequirements(),
    'push_notification': PluginNativeRequirements(androidPermissions: [
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.VIBRATE'
    ]),
    'root_detection': PluginNativeRequirements(),
    'safe_area': PluginNativeRequirements(),
    'screen_brightness': PluginNativeRequirements(),
    'screenshot': PluginNativeRequirements(),
    'sensors': PluginNativeRequirements(iosUsageDescriptions: {
      'NSMotionUsageDescription': 'Motion data access'
    }),
    'shake_detection': PluginNativeRequirements(iosUsageDescriptions: {
      'NSMotionUsageDescription': 'Motion data access'
    }),
    'share_target': PluginNativeRequirements(),
    'sim_info': PluginNativeRequirements(androidPermissions: [
      'android.permission.READ_PHONE_STATE',
      'android.permission.READ_PHONE_NUMBERS'
    ], androidFeatures: [
      'android.hardware.telephony'
    ]),
    'social_login': PluginNativeRequirements(),
    'socket': PluginNativeRequirements(androidPermissions: [
      'android.permission.ACCESS_WIFI_STATE',
      'android.permission.CHANGE_WIFI_MULTICAST_STATE'
    ], iosUsageDescriptions: {
      'NSLocalNetworkUsageDescription':
          'Connects to devices on your local network'
    }),
    'splash_screen': PluginNativeRequirements(),
    'ssh_client': PluginNativeRequirements(iosUsageDescriptions: {
      'NSLocalNetworkUsageDescription':
          'Connects to devices on your local network'
    }),
    'ssh_server': PluginNativeRequirements(iosUsageDescriptions: {
      'NSLocalNetworkUsageDescription':
          'Connects to devices on your local network'
    }),
    'tcp_server': PluginNativeRequirements(iosUsageDescriptions: {
      'NSLocalNetworkUsageDescription':
          'Connects to devices on your local network'
    }),
    'text_zoom': PluginNativeRequirements(),
    'toast': PluginNativeRequirements(),
    'udp_server': PluginNativeRequirements(androidPermissions: [
      'android.permission.ACCESS_WIFI_STATE',
      'android.permission.CHANGE_WIFI_MULTICAST_STATE'
    ], iosUsageDescriptions: {
      'NSLocalNetworkUsageDescription':
          'Connects to devices on your local network'
    }),
    'volume_buttons': PluginNativeRequirements(),
    'wake_lock': PluginNativeRequirements(),
    'websocket': PluginNativeRequirements(),
    'websocket_server': PluginNativeRequirements(iosUsageDescriptions: {
      'NSLocalNetworkUsageDescription':
          'Connects to devices on your local network'
    }),
    'wifi_advanced': PluginNativeRequirements(androidPermissions: [
      'android.permission.ACCESS_WIFI_STATE',
      'android.permission.CHANGE_WIFI_STATE',
      'android.permission.ACCESS_NETWORK_STATE',
      'android.permission.ACCESS_FINE_LOCATION'
    ], iosUsageDescriptions: {
      'NSLocationWhenInUseUsageDescription':
          'Location access to read WiFi information'
    }),
    'wifi_manager': PluginNativeRequirements(),
    'zip': PluginNativeRequirements(),
  };
}

/// One plugin's native requirements, whichever table they come from.
class NativeRequirement {
  const NativeRequirement({
    required this.id,
    required this.androidPermissions,
    required this.androidFeatures,
    required this.iosUsageDescriptions,
  });

  /// Plugin directory name (the key in sweetmelon.yaml).
  final String id;
  final List<String> androidPermissions;
  final List<String> androidFeatures;
  final Map<String, String> iosUsageDescriptions;
}

/// Requirements of every plugin: [PluginRegistryData.allPlugins] first, then
/// [PluginNativeRequirementsData.byPlugin]. The two tables must not overlap.
List<NativeRequirement> allNativeRequirements() => [
      for (final plugin in PluginRegistryData.allPlugins)
        NativeRequirement(
          id: plugin.id,
          androidPermissions: plugin.androidPermissions,
          androidFeatures: plugin.androidFeatures,
          iosUsageDescriptions: plugin.iosPermissions,
        ),
      for (final entry in PluginNativeRequirementsData.byPlugin.entries)
        NativeRequirement(
          id: entry.key,
          androidPermissions: entry.value.androidPermissions,
          androidFeatures: entry.value.androidFeatures,
          iosUsageDescriptions: entry.value.iosUsageDescriptions,
        ),
    ];
