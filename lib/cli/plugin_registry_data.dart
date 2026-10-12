/// اطلاعات کامل هر پلاگین: نام، dependency، permission، import، registration
class PluginRegistryData {
  static const List<PluginDefinition> allPlugins = [
    // ── فاز ۱ ──
    PluginDefinition(
      id: 'permission',
      dartClassName: 'PermissionPlugin',
      jsNamespace: 'permission',
      importPath:
          'package:sweetmelon/plugins/permission/lib/permission_plugin.dart',
      registrationCode:
          "PermissionPlugin(permissionManager: sl<PermissionManager>())",
      needsEmitter: false,
      dependencies: {'permission_handler': '^11.3.0'},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Permission management',
    ),
    PluginDefinition(
      id: 'app_lifecycle',
      dartClassName: 'AppLifecyclePlugin',
      jsNamespace: 'appLifecycle',
      importPath:
          'package:sweetmelon/plugins/app_lifecycle/lib/app_lifecycle_plugin.dart',
      registrationCode: "AppLifecyclePlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {},
      androidPermissions: [],
      iosPermissions: {},
      description: 'App lifecycle events',
    ),
    PluginDefinition(
      id: 'device_info',
      dartClassName: 'DeviceInfoBridgePlugin',
      jsNamespace: 'deviceInfo',
      importPath:
          'package:sweetmelon/plugins/device_info/lib/device_info_plugin.dart',
      registrationCode: "DeviceInfoBridgePlugin()",
      needsEmitter: false,
      dependencies: {
        'device_info_plus': '^10.1.2',
        'package_info_plus': '^8.0.2',
      },
      androidPermissions: [],
      iosPermissions: {},
      description: 'Device and app info',
    ),
    PluginDefinition(
      id: 'connectivity',
      dartClassName: 'ConnectivityBridgePlugin',
      jsNamespace: 'connectivity',
      importPath:
          'package:sweetmelon/plugins/connectivity/lib/connectivity_plugin.dart',
      registrationCode: "ConnectivityBridgePlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {'connectivity_plus': '^6.0.5'},
      androidPermissions: ['android.permission.ACCESS_NETWORK_STATE'],
      iosPermissions: {},
      description: 'Network connectivity',
    ),
    PluginDefinition(
      id: 'storage',
      dartClassName: 'StoragePlugin',
      jsNamespace: 'storage',
      importPath: 'package:sweetmelon/plugins/storage/lib/storage_plugin.dart',
      registrationCode: "StoragePlugin()",
      needsEmitter: false,
      dependencies: {'shared_preferences': '^2.2.2'},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Key-value storage',
    ),
    PluginDefinition(
      id: 'file_system',
      dartClassName: 'FileSystemPlugin',
      jsNamespace: 'fileSystem',
      importPath:
          'package:sweetmelon/plugins/file_system/lib/file_system_plugin.dart',
      registrationCode: "FileSystemPlugin()",
      needsEmitter: false,
      dependencies: {
        'path_provider': '^2.1.1',
        'path': '^1.9.0',
      },
      androidPermissions: [],
      iosPermissions: {},
      description: 'Sandboxed file system',
    ),
    PluginDefinition(
      id: 'http_native',
      dartClassName: 'HttpNativePlugin',
      jsNamespace: 'http',
      importPath:
          'package:sweetmelon/plugins/http_native/lib/http_native_plugin.dart',
      registrationCode: "HttpNativePlugin()",
      needsEmitter: false,
      dependencies: {
        'http': '^1.1.2',
        'mime': '^1.0.5',
      },
      androidPermissions: ['android.permission.INTERNET'],
      iosPermissions: {},
      description: 'Native HTTP client',
    ),
    PluginDefinition(
      id: 'intent_link',
      dartClassName: 'IntentLinkPlugin',
      jsNamespace: 'intent',
      importPath:
          'package:sweetmelon/plugins/intent_link/lib/intent_link_plugin.dart',
      registrationCode: "IntentLinkPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {
        'url_launcher': '^6.3.0',
        'app_links': '^6.3.2',
      },
      androidPermissions: [],
      iosPermissions: {},
      description: 'URL launcher and deep links',
    ),
    PluginDefinition(
      id: 'clipboard',
      dartClassName: 'ClipboardPlugin',
      jsNamespace: 'clipboard',
      importPath:
          'package:sweetmelon/plugins/clipboard/lib/clipboard_plugin.dart',
      registrationCode: "ClipboardPlugin()",
      needsEmitter: false,
      dependencies: {},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Clipboard access',
    ),
    PluginDefinition(
      id: 'share',
      dartClassName: 'ShareBridgePlugin',
      jsNamespace: 'share',
      importPath: 'package:sweetmelon/plugins/share/lib/share_plugin.dart',
      registrationCode: "ShareBridgePlugin()",
      needsEmitter: false,
      dependencies: {
        'share_plus': '^10.0.2',
        'cross_file': '^0.3.4+2',
      },
      androidPermissions: [],
      iosPermissions: {},
      description: 'Native share sheet',
    ),
    PluginDefinition(
      id: 'camera',
      dartClassName: 'CameraPlugin',
      jsNamespace: 'camera',
      importPath: 'package:sweetmelon/plugins/camera/lib/camera_plugin.dart',
      registrationCode: "CameraPlugin()",
      needsEmitter: false,
      dependencies: {'image_picker': '^1.0.4'},
      androidPermissions: [
        'android.permission.CAMERA',
      ],
      iosPermissions: {
        'NSCameraUsageDescription': 'Camera access for photos',
        'NSPhotoLibraryUsageDescription': 'Photo library access',
      },
      description: 'Camera and gallery',
    ),
    PluginDefinition(
      id: 'geolocation',
      dartClassName: 'GeolocationPlugin',
      jsNamespace: 'geolocation',
      importPath:
          'package:sweetmelon/plugins/geolocation/lib/geolocation_plugin.dart',
      registrationCode: "GeolocationPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {'geolocator': '^10.1.0'},
      androidPermissions: [
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
      ],
      iosPermissions: {
        'NSLocationWhenInUseUsageDescription': 'Location access',
      },
      description: 'GPS location',
    ),

    // ── فاز ۳ ──
    PluginDefinition(
      id: 'back_button',
      dartClassName: 'BackButtonPlugin',
      jsNamespace: 'backButton',
      importPath:
          'package:sweetmelon/plugins/back_button/lib/back_button_plugin.dart',
      registrationCode: "BackButtonPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Android back button',
    ),
    PluginDefinition(
      id: 'secure_storage',
      dartClassName: 'SecureStoragePlugin',
      jsNamespace: 'secureStorage',
      importPath:
          'package:sweetmelon/plugins/secure_storage/lib/secure_storage_plugin.dart',
      registrationCode: "SecureStoragePlugin()",
      needsEmitter: false,
      dependencies: {'flutter_secure_storage': '^9.2.2'},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Encrypted storage',
    ),
    PluginDefinition(
      id: 'notification',
      dartClassName: 'NotificationPlugin',
      jsNamespace: 'notification',
      importPath:
          'package:sweetmelon/plugins/notification/lib/notification_plugin.dart',
      registrationCode: "NotificationPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {'flutter_local_notifications': '^17.2.4'},
      androidPermissions: [
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.VIBRATE',
      ],
      iosPermissions: {},
      description: 'Local notifications',
    ),
    PluginDefinition(
      id: 'status_bar',
      dartClassName: 'StatusBarPlugin',
      jsNamespace: 'statusBar',
      importPath:
          'package:sweetmelon/plugins/status_bar/lib/status_bar_plugin.dart',
      registrationCode: "StatusBarPlugin()",
      needsEmitter: false,
      dependencies: {},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Status bar control',
    ),
    PluginDefinition(
      id: 'orientation',
      dartClassName: 'OrientationPlugin',
      jsNamespace: 'orientation',
      importPath:
          'package:sweetmelon/plugins/orientation/lib/orientation_plugin.dart',
      registrationCode: "OrientationPlugin()",
      needsEmitter: false,
      dependencies: {},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Screen orientation',
    ),
    PluginDefinition(
      id: 'haptic',
      dartClassName: 'HapticPlugin',
      jsNamespace: 'haptic',
      importPath: 'package:sweetmelon/plugins/haptic/lib/haptic_plugin.dart',
      registrationCode: "HapticPlugin()",
      needsEmitter: false,
      dependencies: {},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Vibration feedback',
    ),
    PluginDefinition(
      id: 'keyboard',
      dartClassName: 'KeyboardPlugin',
      jsNamespace: 'keyboard',
      importPath:
          'package:sweetmelon/plugins/keyboard/lib/keyboard_plugin.dart',
      registrationCode: "KeyboardPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Keyboard state',
    ),

    // ── فاز ۴ ──
    PluginDefinition(
      id: 'biometrics',
      dartClassName: 'BiometricsPlugin',
      jsNamespace: 'biometrics',
      importPath:
          'package:sweetmelon/plugins/biometrics/lib/biometrics_plugin.dart',
      registrationCode: "BiometricsPlugin()",
      needsEmitter: false,
      dependencies: {'local_auth': '^2.3.0'},
      androidPermissions: [
        'android.permission.USE_BIOMETRIC',
        'android.permission.USE_FINGERPRINT',
      ],
      iosPermissions: {
        'NSFaceIDUsageDescription': 'Biometric authentication',
      },
      description: 'Fingerprint / Face ID',
    ),
    PluginDefinition(
      id: 'qr_scanner',
      dartClassName: 'QrScannerPlugin',
      jsNamespace: 'qrScanner',
      importPath:
          'package:sweetmelon/plugins/qr_scanner/lib/qr_scanner_plugin.dart',
      registrationCode: "QrScannerPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {'mobile_scanner': '^5.2.3'},
      androidPermissions: ['android.permission.CAMERA'],
      iosPermissions: {
        'NSCameraUsageDescription': 'Camera for QR scanning',
      },
      description: 'QR and barcode scanner',
    ),
    PluginDefinition(
      id: 'audio',
      dartClassName: 'AudioPlugin',
      jsNamespace: 'audio',
      importPath: 'package:sweetmelon/plugins/audio/lib/audio_plugin.dart',
      registrationCode: "AudioPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {
        'record': '^5.1.2',
        'audioplayers': '^6.1.0',
      },
      androidPermissions: [
        'android.permission.RECORD_AUDIO',
        'android.permission.FOREGROUND_SERVICE',
      ],
      iosPermissions: {
        'NSMicrophoneUsageDescription': 'Microphone for audio recording',
      },
      description: 'Audio recorder and player',
    ),
    PluginDefinition(
      id: 'sms_otp',
      dartClassName: 'SmsOtpPlugin',
      jsNamespace: 'smsOtp',
      importPath: 'package:sweetmelon/plugins/sms_otp/lib/sms_otp_plugin.dart',
      registrationCode: "SmsOtpPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {'sms_autofill': '^2.4.0'},
      androidPermissions: [
        'android.permission.RECEIVE_SMS',
        'android.permission.READ_SMS',
      ],
      iosPermissions: {},
      description: 'SMS OTP auto-read',
    ),
    PluginDefinition(
      id: 'download_manager',
      dartClassName: 'DownloadManagerPlugin',
      jsNamespace: 'downloadManager',
      importPath:
          'package:sweetmelon/plugins/download_manager/lib/download_manager_plugin.dart',
      registrationCode: "DownloadManagerPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Download with progress',
    ),
    PluginDefinition(
      id: 'database',
      dartClassName: 'DatabasePlugin',
      jsNamespace: 'database',
      importPath:
          'package:sweetmelon/plugins/database/lib/database_plugin.dart',
      registrationCode: "DatabasePlugin()",
      needsEmitter: false,
      dependencies: {'sqflite': '^2.3.3+2'},
      androidPermissions: [],
      iosPermissions: {},
      description: 'SQLite database',
    ),
    PluginDefinition(
      id: 'contacts',
      dartClassName: 'ContactsPlugin',
      jsNamespace: 'contacts',
      importPath:
          'package:sweetmelon/plugins/contacts/lib/contacts_plugin.dart',
      registrationCode: "ContactsPlugin()",
      needsEmitter: false,
      dependencies: {'flutter_contacts': '^1.1.9+2'},
      androidPermissions: [
        'android.permission.READ_CONTACTS',
        'android.permission.WRITE_CONTACTS',
      ],
      iosPermissions: {
        'NSContactsUsageDescription': 'Contacts access',
      },
      description: 'Read contacts',
    ),
    PluginDefinition(
      id: 'phone_dialer',
      dartClassName: 'PhoneDialerPlugin',
      jsNamespace: 'phoneDialer',
      importPath:
          'package:sweetmelon/plugins/phone_dialer/lib/phone_dialer_plugin.dart',
      registrationCode: "PhoneDialerPlugin()",
      needsEmitter: false,
      dependencies: {},
      androidPermissions: [
        'android.permission.CALL_PHONE',
      ],
      iosPermissions: {},
      description: 'Phone, SMS, Email',
    ),

    // ── فاز ۵ ──
    PluginDefinition(
      id: 'bluetooth',
      dartClassName: 'BluetoothPlugin',
      jsNamespace: 'bluetooth',
      importPath:
          'package:sweetmelon/plugins/bluetooth/lib/bluetooth_plugin.dart',
      registrationCode: "BluetoothPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {'flutter_blue_plus': '^1.32.12'},
      androidPermissions: [
        'android.permission.BLUETOOTH',
        'android.permission.BLUETOOTH_ADMIN',
        'android.permission.BLUETOOTH_SCAN',
        'android.permission.BLUETOOTH_CONNECT',
        'android.permission.BLUETOOTH_ADVERTISE',
      ],
      iosPermissions: {
        'NSBluetoothAlwaysUsageDescription': 'Bluetooth access',
      },
      description: 'Bluetooth BLE',
    ),
    PluginDefinition(
      id: 'nfc',
      dartClassName: 'NfcPlugin',
      jsNamespace: 'nfc',
      importPath: 'package:sweetmelon/plugins/nfc/lib/nfc_plugin.dart',
      registrationCode: "NfcPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {'nfc_manager': '^3.5.0'},
      androidPermissions: ['android.permission.NFC'],
      iosPermissions: {},
      androidFeatures: ['android.hardware.nfc'],
      description: 'NFC read/write',
    ),
    PluginDefinition(
      id: 'speech_to_text',
      dartClassName: 'SpeechToTextPlugin',
      jsNamespace: 'speechToText',
      importPath:
          'package:sweetmelon/plugins/speech_to_text/lib/speech_to_text_plugin.dart',
      registrationCode: "SpeechToTextPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {'speech_to_text': '^7.0.0'},
      androidPermissions: ['android.permission.RECORD_AUDIO'],
      iosPermissions: {
        'NSSpeechRecognitionUsageDescription': 'Speech recognition',
        'NSMicrophoneUsageDescription': 'Microphone for speech',
      },
      description: 'Voice recognition',
    ),
    PluginDefinition(
      id: 'text_to_speech',
      dartClassName: 'TextToSpeechPlugin',
      jsNamespace: 'textToSpeech',
      importPath:
          'package:sweetmelon/plugins/text_to_speech/lib/text_to_speech_plugin.dart',
      registrationCode: "TextToSpeechPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {'flutter_tts': '^4.0.2'},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Text to speech',
    ),
    PluginDefinition(
      id: 'video_player',
      dartClassName: 'VideoPlayerPlugin',
      jsNamespace: 'videoPlayer',
      importPath:
          'package:sweetmelon/plugins/video_player/lib/video_player_plugin.dart',
      registrationCode: "VideoPlayerPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {'video_player': '^2.9.2'},
      androidPermissions: [],
      iosPermissions: {},
      description: 'Video playback',
    ),
    PluginDefinition(
      id: 'in_app_browser',
      dartClassName: 'InAppBrowserPlugin',
      jsNamespace: 'inAppBrowser',
      importPath:
          'package:sweetmelon/plugins/in_app_browser/lib/in_app_browser_plugin.dart',
      registrationCode: "InAppBrowserPlugin(eventEmitter: emitter)",
      needsEmitter: true,
      dependencies: {'flutter_inappwebview': '^6.1.5'},
      androidPermissions: [],
      iosPermissions: {},
      description: 'In-app browser',
    ),
    PluginDefinition(
      id: 'pdf',
      dartClassName: 'PdfBridgePlugin',
      jsNamespace: 'pdf',
      importPath:
          'package:sweetmelon/plugins/pdf_plugin/lib/pdf_bridge_plugin.dart',
      registrationCode: "PdfBridgePlugin()",
      needsEmitter: false,
      dependencies: {
        'pdf': '^3.11.1',
        'printing': '^5.13.3',
      },
      androidPermissions: [],
      iosPermissions: {},
      description: 'PDF generate and print',
    ),
    PluginDefinition(
      id: 'encryption',
      dartClassName: 'EncryptionPlugin',
      jsNamespace: 'encryption',
      importPath:
          'package:sweetmelon/plugins/encryption/lib/encryption_plugin.dart',
      registrationCode: "EncryptionPlugin()",
      needsEmitter: false,
      dependencies: {
        'encrypt': '^5.0.3',
        'pointycastle': '^3.9.1',
      },
      androidPermissions: [],
      iosPermissions: {},
      description: 'AES, SHA, HMAC encryption',
    ),
  ];
}

class PluginDefinition {
  final String id;
  final String dartClassName;
  final String jsNamespace;
  final String importPath;
  final String registrationCode;
  final bool needsEmitter;
  final Map<String, String> dependencies;
  final List<String> androidPermissions;
  final Map<String, String> iosPermissions;
  final List<String> androidFeatures;
  final String description;

  const PluginDefinition({
    required this.id,
    required this.dartClassName,
    required this.jsNamespace,
    required this.importPath,
    required this.registrationCode,
    required this.needsEmitter,
    required this.dependencies,
    required this.androidPermissions,
    required this.iosPermissions,
    this.androidFeatures = const [],
    required this.description,
  });
}
