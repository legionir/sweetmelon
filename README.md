<p align="center">
  <img src="assets/branding/logo.png" alt="Sweetmelon logo" width="160" />
</p>

<h1 align="center">Sweetmelon — Flutter Native Bridge</h1>

**Run any web app — Angular, React, Vue, or plain HTML/CSS/JS — inside a native Flutter shell with full access to 104 native plugins through a unified JavaScript SDK.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](License)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%5E3.0-0175C2.svg)](https://dart.dev)
[![Plugins](https://img.shields.io/badge/plugins-104-success.svg)](#-plugin-catalog)
[![Methods](https://img.shields.io/badge/native_methods-714-success.svg)](#-plugin-catalog)
[![Tests](https://img.shields.io/badge/tests-500%2B-brightgreen.svg)](#-testing)

Sweetmelon bridges the gap between web technology and native device capabilities. Your frontend stays 100% web (deployed as static assets inside the app), while a JSON message bridge gives it controlled, permission-gated access to cameras, sensors, Bluetooth, file systems, push notifications, Firebase, local servers, and much more.

---

## ✨ Highlights

- 🔌 **104 plugins** exposing **714 native methods** and **74 event streams** behind one JS API — `window.NativeSDK`
- 🌐 **Framework-agnostic** — works with Angular, React, Vue, Svelte, or vanilla JS; ships with a TypeScript definition file (`native-sdk.d.ts`)
- 🧱 **Modular core** — bridge protocol, plugin engine, security, performance, and devtools are separate internal packages
- 🔐 **Security first** — JS↔native permission manager, rate limiter, execution guard, SSL pinning, isolated `SecurityContext`, and sandboxed asset serving
- ⚡ **Lazy plugin loading** — plugins are loaded on first use with preload/unload control and a `_loader` diagnostics plugin
- 🔄 **Live updates** — ship updated `www` bundles over the air without a store release (`liveUpdater`), with rollback and release channels
- 📡 **Device-as-a-server** — run HTTP, WebSocket, TCP, UDP, FTP, and SSH servers on the device for LAN/P2P scenarios
- 🧪 **Heavily tested** — 500+ unit/widget tests with a CI coverage gate

---

## 🏗 Architecture

```
┌──────────────────────────────────────────────────────┐
│                    JS / HTML App                     │
│   (Angular, React, Vue, or vanilla HTML/JS/CSS)      │
├──────────────────────────────────────────────────────┤
│                  window.NativeSDK                    │
│             (native-sdk.js — JS wrapper)             │
├──────────────────────────────────────────────────────┤
│                 window.Native.call()                 │
│           (Bridge SDK injected by Flutter)           │
├──────────────────────────────────────────────────────┤
│                 Message Bridge (Dart)                │
│        JSON message protocol over JS channels        │
├──────────────────────────────────────────────────────┤
│                 Plugin Manager (Dart)                │
│   Permissions • Rate limiting • Caching • Guards     │
├──────────────────────────────────────────────────────┤
│      Plugin Registry + Lazy Loader (Dart)            │
│          104 plugins, loaded on demand               │
├──────────────────────────────────────────────────────┤
│              Android / iOS Native APIs               │
└──────────────────────────────────────────────────────┘
```

### Call flow

1. JS calls `NativeSDK.<plugin>.<method>(...)`, which wraps `window.Native.call({ plugin, method, args })`.
2. The Dart **bridge** deserializes the JSON message and hands it to the **plugin manager**.
3. The manager runs the **permission check**, **rate limiter**, **execution guard**, and optional **cache** middleware.
4. The **lazy loader** ensures the plugin instance is initialized, then dispatches to `plugin.onCall(method, args)`.
5. Results (or typed errors) travel back as JSON; native-initiated traffic flows to JS as events via the registered event emitter.

---

## 🚀 Getting Started

### Prerequisites

- Flutter 3.x with Dart ≥ 3.0
- Android SDK (primary platform) and/or Xcode for iOS

### Run the example app

This repository is the **framework** (the "core"). It ships a default web app in `assets/www` — the **Native Bridge Test Suite**, a page with a panel for every enabled plugin — so you can verify the bridge on a device (filter by name or group, collapse panels, and see which plugins are not enabled in the current build):

```bash
git clone https://github.com/legionir/sweetmelon.git
cd sweetmelon
flutter pub get
flutter run
```

The example loads from the bundled `assets/www` directory — no dev server is required in production builds. During web development you can point the app at a dev URL instead (see `docs/guide/`).

### Four ways to use the core

| Mode | You keep | How |
| --- | --- | --- |
| **Action** (`ref`) | `www/`, `sweetmelon.yaml`, icon | `uses: legionir/sweetmelon@v2.4.1` in your workflow. [Guide](docs/guide/build-from-web.md) |
| **Template** | the same, started from a template | `dart run bin/sweetmelon.dart init ../my-app --package-name com.acme.app --app-name "My App" --apply` |
| **Clone / fork** | the whole project | Clone or fork at a release tag (`v2.4.0`), write the app, run the build workflow. Take patch releases with `git merge v2.4.1`. |
| **Package** | your own Flutter shell | `sweetmelon:` as a git dependency (below). |

The core is versioned with [SemVer](https://semver.org): patch releases (`2.4.x`) only fix bugs, so an app pinned to `2.4` is never broken by them; a new minor or major is taken on purpose. See [CHANGELOG.md](CHANGELOG.md) and the [versioning guide](docs/guide/versioning.md).

### Use the core in your own app

An application keeps its own web UI, Flutter shell, and native projects, and depends on the core as a package:

```yaml
# pubspec.yaml
dependencies:
  sweetmelon:
    git:
      url: https://github.com/legionir/sweetmelon.git
      ref: v2.4.1   # an exact tag; patch releases (v2.4.2 ...) only fix bugs
```

Then, in the app:

1. Wire the services and the plugins you need in your own `lib/di/service_locator.dart` (use [`lib/di/service_locator.dart`](lib/di/service_locator.dart) as the template; import from `package:sweetmelon/...`).
2. Add the Flutter packages of any plugin you enable to the app's `pubspec.yaml` (the core declares dependencies only for its default plugin set), and the permissions it needs to the app's `AndroidManifest.xml` / `Info.plist`.
3. Copy `assets/www/js/native-sdk.js`, `native-sdk.d.ts` and `native-resilience.js` into the app's `assets/www/js` and include `native-sdk.js` in your HTML.

**Reference application:** [MelonAI Studio](https://github.com/legionir/sweet-melon-ai-client) — a multi-provider AI chat client built this way.

### Project structure

```
sweetmelon/
├── android/                      # Android host project for the example app
├── ios/                          # iOS host project for the example app
├── web/                          # Flutter web target
├── assets/
│   ├── www/                      # Default test-suite web app + the JavaScript SDK
│   │   ├── index.html            # Test-suite entry point
│   │   ├── css/styles.css
│   │   ├── img/logo.png          # Logo (transparent PNG)
│   │   └── js/
│   │       ├── native-sdk.js         # NativeSDK wrapper (copy this into your app)
│   │       ├── native-sdk.d.ts       # TypeScript definitions
│   │       ├── native-resilience.js  # Retry manager, circuit breaker, offline queue
│   │       ├── ui.js                 # Page behaviour: filter, groups, collapsible panels
│   │       └── app.js                # Test-suite page logic (one handler per button)
│   ├── framework-sdks/           # Angular / React / Vue / RxJS helpers
│   └── devtools/                 # Bridge inspector page
├── lib/
│   ├── main.dart                 # Example app entry
│   ├── app.dart                  # MaterialApp
│   ├── di/service_locator.dart   # Dependency injection (generated section is managed by `sweetmelon sync`)
│   ├── screens/                  # WebView host screen
│   ├── cli/                      # Implementation of the sweetmelon CLI
│   ├── packages/                 # Internal framework packages
│   │   ├── core/                 # Bridge, protocol, WebView host, runtime, SSL pinning, asset server
│   │   ├── plugin_engine/        # Plugin base, registry, manager, lazy loader, versioning
│   │   ├── security/             # Permission manager, rate limiter, execution guard
│   │   ├── performance/          # Cache manager
│   │   └── devtools/             # Bridge inspector
│   └── plugins/                  # 104 native plugins (each with its own README)
├── bin/sweetmelon.dart           # CLI (create / plugin / configure / validate / list / build / doctor / sync / rename / icon / bump)
├── tool/                         # plugin_catalog.json and the generated test target list
├── docs/                         # VitePress documentation site sources
├── test/                         # Unit, widget & integration tests
├── integration_test/             # On-device end-to-end checks
├── .github/                      # CI workflows and helper scripts
└── sweetmelon.yaml               # Plugin enable/disable configuration
```

---

## 💻 JavaScript SDK

Everything is exposed through the global `NativeSDK` object. Full typings are in [`assets/www/js/native-sdk.d.ts`](assets/www/js/native-sdk.d.ts).

```javascript
// Await bridge readiness
await NativeSDK.waitForReady();

// Call a plugin method — every call returns a Promise of a plain object
const { ip } = await NativeSDK.networkInfo.getLocalIp();
await NativeSDK.storage.set('theme', 'dark');
const value = await NativeSDK.storage.get('theme');

// Subscribe to native events
const off = NativeSDK.on('connectivity.change', (data) => {
  console.log('Network changed:', data);
});
off(); // unsubscribe

// Batch multiple calls in one round-trip
const results = await NativeSDK.batch([
  { plugin: 'deviceInfo', method: 'getDeviceInfo', args: {} },
  { plugin: 'storage', method: 'get', args: { key: 'theme' } },
]);
```

Every plugin documents its methods, parameters, return shapes, and events in its own README — linked from the catalog below.

---

## 🔌 Plugin Catalog

**104 plugins · 714 methods · 74 event types.** Each link opens the plugin's dedicated README with the full API reference and usage examples.

### Device & System

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`deviceInfo`](lib/plugins/device_info/README.md) | `NativeSDK.deviceInfo` | Device and app info plugin |
| [`appLifecycle`](lib/plugins/app_lifecycle/README.md) | `NativeSDK.appLifecycle` | App lifecycle state bridge |
| [`simInfo`](lib/plugins/sim_info/README.md) | `NativeSDK.simInfo` | SIM card information plugin |
| [`rootDetection`](lib/plugins/root_detection/README.md) | `NativeSDK.rootDetection` | Detect rooted/jailbroken devices |
| [`appIntegrity`](lib/plugins/app_integrity/README.md) | `NativeSDK.appIntegrity` | Device integrity checks (Play Integrity on Android) |
| [`clipboard`](lib/plugins/clipboard/README.md) | `NativeSDK.clipboard` | Clipboard text plugin |
| [`backButton`](lib/plugins/back_button/README.md) | `NativeSDK.backButton` | Android back button and system navigation plugin |
| [`wakeLock`](lib/plugins/wake_lock/README.md) | `NativeSDK.wakeLock` | Keep screen awake / wake lock plugin |
| [`kioskMode`](lib/plugins/kiosk_mode/README.md) | `NativeSDK.kioskMode` | Lock device into kiosk mode |
| [`privacyScreen`](lib/plugins/privacy_screen/README.md) | `NativeSDK.privacyScreen` | Block screenshots and app-switcher previews |
| [`accessibility`](lib/plugins/accessibility/README.md) | `NativeSDK.accessibility` | Accessibility and screen reader plugin |
| [`nativeSettings`](lib/plugins/native_settings/README.md) | `NativeSDK.nativeSettings` | Open native system settings screens |
| [`intentLauncher`](lib/plugins/intent_launcher/README.md) | `NativeSDK.intentLauncher` | Launch Android intents and system screens |
| [`intent`](lib/plugins/intent_link/README.md) | `NativeSDK.intent` | Deep links & URL/intent launching |

### System UI & Haptics

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`statusBar`](lib/plugins/status_bar/README.md) | `NativeSDK.statusBar` | Status bar and system UI control plugin |
| [`navigationBar`](lib/plugins/navigation_bar/README.md) | `NativeSDK.navigationBar` | Android navigation bar color & style control |
| [`orientation`](lib/plugins/orientation/README.md) | `NativeSDK.orientation` | Screen orientation control plugin |
| [`screenBrightness`](lib/plugins/screen_brightness/README.md) | `NativeSDK.screenBrightness` | Control device screen brightness |
| [`flashlight`](lib/plugins/flashlight/README.md) | `NativeSDK.flashlight` | Flashlight / torch control plugin |
| [`keyboard`](lib/plugins/keyboard/README.md) | `NativeSDK.keyboard` | Keyboard visibility and height plugin |
| [`safeArea`](lib/plugins/safe_area/README.md) | `NativeSDK.safeArea` | Get safe area insets (notch, status bar, etc) |
| [`splashScreen`](lib/plugins/splash_screen/README.md) | `NativeSDK.splashScreen` | Splash screen control plugin |
| [`haptic`](lib/plugins/haptic/README.md) | `NativeSDK.haptic` | Haptic feedback and vibration plugin |
| [`shakeDetection`](lib/plugins/shake_detection/README.md) | `NativeSDK.shakeDetection` | Detect device shake gesture |
| [`volumeButtons`](lib/plugins/volume_buttons/README.md) | `NativeSDK.volumeButtons` | Listen to volume button presses |
| [`textZoom`](lib/plugins/text_zoom/README.md) | `NativeSDK.textZoom` | WebView text zoom for accessibility |
| [`badge`](lib/plugins/badge/README.md) | `NativeSDK.badge` | App icon badge count plugin |
| [`screenshot`](lib/plugins/screenshot/README.md) | `NativeSDK.screenshot` | Capture screenshots of the current view |

### Storage & Files

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`storage`](lib/plugins/storage/README.md) | `NativeSDK.storage` | Key-value storage plugin |
| [`secureStorage`](lib/plugins/secure_storage/README.md) | `NativeSDK.secureStorage` | Encrypted key-value secure storage plugin |
| [`database`](lib/plugins/database/README.md) | `NativeSDK.database` | SQLite database plugin |
| [`fileSystem`](lib/plugins/file_system/README.md) | `NativeSDK.fileSystem` | Sandboxed internal file system plugin |
| [`filePicker`](lib/plugins/file_picker/README.md) | `NativeSDK.filePicker` | Pick files, images, videos from device |
| [`fileOpener`](lib/plugins/file_opener/README.md) | `NativeSDK.fileOpener` | Open files with system default app |
| [`fileCompressor`](lib/plugins/file_compressor/README.md) | `NativeSDK.fileCompressor` | Image compression plugin (JPEG, PNG, WebP) |
| [`downloadManager`](lib/plugins/download_manager/README.md) | `NativeSDK.downloadManager` | Download manager with progress events |
| [`zip`](lib/plugins/zip/README.md) | `NativeSDK.zip` | Zip and unzip files plugin |
| [`cacheControl`](lib/plugins/cache_control/README.md) | `NativeSDK.cacheControl` | WebView cache control, clear, and preload plugin |
| [`cookieManager`](lib/plugins/cookie_manager/README.md) | `NativeSDK.cookieManager` | WebView cookie and session management plugin |
| [`mediaManager`](lib/plugins/media_manager/README.md) | `NativeSDK.mediaManager` | Save media to gallery, manage albums |
| [`documentScanner`](lib/plugins/document_scanner/README.md) | `NativeSDK.documentScanner` | Document scanning with auto-crop |
| [`pdf`](lib/plugins/pdf_plugin/README.md) | `NativeSDK.pdf` | PDF generate, view, print plugin |

### Networking & Servers

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`connectivity`](lib/plugins/connectivity/README.md) | `NativeSDK.connectivity` | Network connectivity plugin |
| [`http`](lib/plugins/http_native/README.md) | `NativeSDK.http` | Native HTTP client plugin |
| [`websocket`](lib/plugins/websocket/README.md) | `NativeSDK.websocket` | WebSocket real-time communication plugin |
| [`networkInfo`](lib/plugins/network_info/README.md) | `NativeSDK.networkInfo` | Network interfaces, IPs, and diagnostics |
| [`pingDns`](lib/plugins/ping_dns/README.md) | `NativeSDK.pingDns` | Ping hosts and DNS lookup |
| [`socket`](lib/plugins/socket/README.md) | `NativeSDK.socket` | Raw TCP and UDP socket plugin |
| [`tcpServer`](lib/plugins/tcp_server/README.md) | `NativeSDK.tcpServer` | TCP server for accepting incoming connections |
| [`udpServer`](lib/plugins/udp_server/README.md) | `NativeSDK.udpServer` | UDP server for receiving datagrams |
| [`httpServer`](lib/plugins/http_server/README.md) | `NativeSDK.httpServer` | Local HTTP/HTTPS server plugin |
| [`websocketServer`](lib/plugins/websocket_server/README.md) | `NativeSDK.websocketServer` | WebSocket server for P2P communication |
| [`sshClient`](lib/plugins/ssh_client/README.md) | `NativeSDK.sshClient` | SSH client for remote server management |
| [`sshServer`](lib/plugins/ssh_server/README.md) | `NativeSDK.sshServer` | Command server with SSH-like interface |
| [`ftpClient`](lib/plugins/ftp_client/README.md) | `NativeSDK.ftpClient` | FTP client for file transfer |
| [`ftpServer`](lib/plugins/ftp_server/README.md) | `NativeSDK.ftpServer` | FTP server for file sharing on local network |

### Location & Wireless

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`geolocation`](lib/plugins/geolocation/README.md) | `NativeSDK.geolocation` | Geolocation and GPS plugin |
| [`backgroundGeolocation`](lib/plugins/background_geolocation/README.md) | `NativeSDK.backgroundGeolocation` | Background geolocation tracking plugin |
| [`nfc`](lib/plugins/nfc/README.md) | `NativeSDK.nfc` | NFC read/write plugin |
| [`bluetooth`](lib/plugins/bluetooth/README.md) | `NativeSDK.bluetooth` | Bluetooth Low Energy (BLE) plugin |
| [`qrScanner`](lib/plugins/qr_scanner/README.md) | `NativeSDK.qrScanner` | QR and barcode scanner plugin |
| [`wifiManager`](lib/plugins/wifi_manager/README.md) | `NativeSDK.wifiManager` | WiFi network information and management |
| [`wifiAdvanced`](lib/plugins/wifi_advanced/README.md) | `NativeSDK.wifiAdvanced` | Advanced WiFi: scan, connect, hotspot, direct |

### Motion & Sensors

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`sensors`](lib/plugins/sensors/README.md) | `NativeSDK.sensors` | Accelerometer, gyroscope & magnetometer streams |
| [`pedometer`](lib/plugins/pedometer/README.md) | `NativeSDK.pedometer` | Step counter and pedestrian status plugin |

### Media & AV

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`camera`](lib/plugins/camera/README.md) | `NativeSDK.camera` | Camera and image picker plugin |
| [`cameraPreview`](lib/plugins/camera_preview/README.md) | `NativeSDK.cameraPreview` | Native camera preview with custom controls |
| [`audio`](lib/plugins/audio/README.md) | `NativeSDK.audio` | Audio recorder and player plugin |
| [`videoPlayer`](lib/plugins/video_player/README.md) | `NativeSDK.videoPlayer` | Video player plugin |
| [`speechToText`](lib/plugins/speech_to_text/README.md) | `NativeSDK.speechToText` | Speech to text recognition plugin |
| [`textToSpeech`](lib/plugins/text_to_speech/README.md) | `NativeSDK.textToSpeech` | Text to speech plugin |

### UI, Dialogs & Notifications

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`dialog`](lib/plugins/dialog/README.md) | `NativeSDK.dialog` | Native dialog windows: alert, confirm, prompt |
| [`toast`](lib/plugins/toast/README.md) | `NativeSDK.toast` | Native toast notification plugin |
| [`actionSheet`](lib/plugins/action_sheet/README.md) | `NativeSDK.actionSheet` | Bottom sheet action selector plugin |
| [`datePicker`](lib/plugins/date_picker/README.md) | `NativeSDK.datePicker` | Native date and time picker dialogs |
| [`notification`](lib/plugins/notification/README.md) | `NativeSDK.notification` | Local notification plugin |
| [`inAppBrowser`](lib/plugins/in_app_browser/README.md) | `NativeSDK.inAppBrowser` | In-app browser for external pages, OAuth, etc. |

### Contacts & Communication

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`contacts`](lib/plugins/contacts/README.md) | `NativeSDK.contacts` | Contacts read plugin |
| [`phoneDialer`](lib/plugins/phone_dialer/README.md) | `NativeSDK.phoneDialer` | Phone dialer and call plugin |
| [`smsOtp`](lib/plugins/sms_otp/README.md) | `NativeSDK.smsOtp` | SMS OTP auto-read plugin |
| [`emailComposer`](lib/plugins/email_composer/README.md) | `NativeSDK.emailComposer` | Compose and send email with attachments |
| [`share`](lib/plugins/share/README.md) | `NativeSDK.share` | Native share plugin |
| [`shareTarget`](lib/plugins/share_target/README.md) | `NativeSDK.shareTarget` | Receive shared content from other apps |

### Security & Auth

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`permission`](lib/plugins/permission/README.md) | `NativeSDK.permission` | Permission bridge for JS |
| [`encryption`](lib/plugins/encryption/README.md) | `NativeSDK.encryption` | AES/RSA encryption and hashing plugin |
| [`biometrics`](lib/plugins/biometrics/README.md) | `NativeSDK.biometrics` | Fingerprint & face authentication |
| [`oauth2`](lib/plugins/oauth2/README.md) | `NativeSDK.oauth2` | Generic OAuth2 authentication plugin |
| [`socialLogin`](lib/plugins/social_login/README.md) | `NativeSDK.socialLogin` | Social login (Google, phone, anonymous) |

### Firebase

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`firebaseAnalytics`](lib/plugins/firebase_analytics/README.md) | `NativeSDK.firebaseAnalytics` | Firebase Analytics integration |
| [`firebaseAuth`](lib/plugins/firebase_auth/README.md) | `NativeSDK.firebaseAuth` | Firebase Authentication plugin |
| [`firebaseCrashlytics`](lib/plugins/firebase_crashlytics/README.md) | `NativeSDK.firebaseCrashlytics` | Firebase Crashlytics integration |
| [`firebaseRemoteConfig`](lib/plugins/firebase_remote_config/README.md) | `NativeSDK.firebaseRemoteConfig` | Firebase Remote Config integration |
| [`pushNotification`](lib/plugins/push_notification/README.md) | `NativeSDK.pushNotification` | FCM push notifications with topics & permissions |

### Tasks, Scheduling & Services

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`alarm`](lib/plugins/alarm/README.md) | `NativeSDK.alarm` | Timer-based alarm plugin |
| [`calendar`](lib/plugins/calendar/README.md) | `NativeSDK.calendar` | Device calendar read/write plugin |
| [`backgroundTask`](lib/plugins/background_task/README.md) | `NativeSDK.backgroundTask` | Background task scheduler and executor plugin |
| [`foregroundService`](lib/plugins/foreground_service/README.md) | `NativeSDK.foregroundService` | Android foreground service for persistent tasks |

### Store, Updates & Monetization

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`inAppPurchase`](lib/plugins/in_app_purchase/README.md) | `NativeSDK.inAppPurchase` | In-app purchase and subscription plugin |
| [`inAppReview`](lib/plugins/in_app_review/README.md) | `NativeSDK.inAppReview` | In-app review and rating prompt |
| [`nativeMarket`](lib/plugins/native_market/README.md) | `NativeSDK.nativeMarket` | Link to app stores and market pages |
| [`appUpdate`](lib/plugins/app_update/README.md) | `NativeSDK.appUpdate` | App version check and update plugin |
| [`liveUpdater`](lib/plugins/live_updater/README.md) | `NativeSDK.liveUpdater` | Live update plugin for www assets |

### Maps

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`googleMaps`](lib/plugins/google_maps/README.md) | `NativeSDK.googleMaps` | Google Maps geocoding, directions, and places |

### Internal

| Plugin | JS namespace | Description |
|--------|--------------|-------------|
| [`_loader`](lib/plugins/loader_status/README.md) | `NativeSDK._loader` | Internal plugin loader status |
---

## 🧩 Adding Your Own Plugin

Every plugin is a small Dart class living in `lib/plugins/<name>/` with this layout:

```
lib/plugins/my_plugin/
├── README.md                     # API documentation (required)
├── pubspec.yaml
└── lib/
    └── my_plugin_plugin.dart     # Plugin implementation
```

A minimal implementation:

```dart
class MyPluginPlugin extends Plugin {
  @override
  String get name => 'myPlugin';           // JS namespace: NativeSDK.myPlugin

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Does something useful';

  @override
  List<String> get supportedMethods => ['doThing', 'getInfo'];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'doThing':
        final input = args['input'] as String;
        return {'done': true, 'echo': input};
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  // Emit events to JS: eventEmitter?.call('myPlugin.done', {'ok': true});
}
```

Then register it in the service locator, add its namespace to `assets/www/js/native-sdk.js`, and enable it in `sweetmelon.yaml`. The CLI scaffolds all of this:

```bash
dart run bin/sweetmelon.dart plugin add my_plugin
```

### CLI

```bash
dart run bin/sweetmelon.dart <command>

create      Scaffold a new Sweetmelon project
plugin      Add/remove/inspect plugins
configure   Regenerate service_locator.dart from sweetmelon.yaml
validate    Validate sweetmelon.yaml and project files
list        List all plugins and their status
info        Show plugin details
build       Assemble a release build
clean       Clean build artifacts
doctor      Environment and project checks (exit 1 on failure)
sync        Sync pubspec, permissions, app name and web titles with sweetmelon.yaml
              --apply writes, --check exits 1 when files are out of date
rename      Change the Android applicationId / iOS bundle id, or the Dart package name
              --id com.acme.app --apply
              --dart-package my_app --apply   (then run flutter pub get)
icon        Generate Android, iOS and web icons from a square PNG (1024 px or more)
              icon assets/icon.png --apply
bump        Bump the version: build | patch | minor | major (--apply)
prepare     Get a checkout ready to build: inject www, choose plugins, set package name,
              Dart package, app name and icon, then sync (--apply)
detect      List the plugins the web app uses (--www dir, --strict)
init        Create a new app folder that builds with the core as an Action
upgrade     Move an app to another core release (--to 2.4.1, --allow-minor, --apply)
```

`rename --dart-package` rewrites `name:` in `pubspec.yaml`, the dependency key in the plugin pubspecs and every `package:<old>/` import in `lib`, `test`, `integration_test`, `bin` and `tool` (the CLI sources included, so the renamed project keeps working with `sync`). Without `--id` it leaves the Android and iOS ids alone; with both options it changes both.

`sync`, `rename`, `icon`, `bump` and `configure` write through one safe writer: a dry run by default (`--apply` to write), a refusal when git has uncommitted changes (`--force` to override), a backup under `.sweetmelon/backup/`, and rollback when a write fails.

Plugin switches in `sweetmelon.yaml` (`plugin enable <name>` / `plugin disable <name>` flip them): `sync` adds the pubspec dependencies of enabled plugins that are not declared yet (plain version constraints from the plugin's own `pubspec.yaml`; existing entries are never changed), removes unused ones of disabled plugins, and adds or removes the Android permissions, Android features and iOS usage descriptions each enabled plugin needs. Every plugin under `lib/plugins` has an entry (`lib/cli/plugin_registry_data.dart` and `lib/cli/plugin_native_requirements.dart`), and a test fails when a new plugin has none. Manifest components (intent filters, services, `<queries>`) and non-string `Info.plist` values such as `UIBackgroundModes` are not managed and still have to be added by hand where a plugin needs them. `doctor` reports plugins that are disabled but still imported. `sweetmelon.yaml` is the single source of truth: `configure` regenerates `service_locator.dart` from its `enabled` flags, and `sync --check` fails when pubspec, permissions or titles differ from it.

---

## 🧱 Core Packages

| Package | Responsibility |
|---------|----------------|
| [`core`](lib/packages/core) | Bridge protocol, JSON message transport, WebView host, runtime utilities, SSL pinning, bundled asset server |
| [`plugin_engine`](lib/packages/plugin_engine) | `Plugin` base class, registry, plugin manager, lazy loader, versioned plugin manager, migrations |
| [`security`](lib/packages/security) | Permission manager (per-method JS↔native grants), rate limiter, execution guard |
| [`performance`](lib/packages/performance) | Response cache manager for bridge calls |
| [`devtools`](lib/packages/devtools) | Bridge inspector for debugging message traffic |

---

## 🔐 Security Model

- **Permission manager** — native methods can require explicit user grants before JS may invoke them; grants are persisted and revocable.
- **Rate limiter** — per-plugin call throttling protects against runaway web code.
- **Execution guard** — validates plugin availability and method allowlists before dispatch.
- **SSL pinning** — pinned certificates via an isolated `SecurityContext` for update channels and sensitive endpoints.
- **Asset server** — bundled `www` assets are served through a hardened local server that rejects path traversal and serves correct MIME types.
- **Sandboxed file access** — `fileSystem` resolves paths only inside base directories (`documents`, `downloads`, `temporary`, ...) and blocks escaping them.
- **Root/integrity detection** — `rootDetection` and `appIntegrity` let apps adapt to compromised devices.

See [`docs/SECURITY.md`](docs/SECURITY.md) for details.

---

## 🔄 Live Updates

The `liveUpdater` plugin delivers new versions of your `www` bundle over HTTPS, applies them on next start, and supports:

- Release **channels** (`production`, `beta`, ...) via `setChannel`
- Automatic **rollback** when a bundle fails (`update.autoRolledBack` event)
- Delta-free full-bundle updates with version history and status APIs

Combined with the standard `appUpdate` plugin (store-driven updates), you get both instant web updates and store compliance.

---

## 🧪 Testing

```bash
flutter test                 # unit + widget tests
flutter test --coverage      # coverage report
```

- **500+ tests** covering the bridge protocol, plugin engine, security middleware, and every plugin's `onCall`/`validateArgs` contract
- CI enforces a **coverage gate** (current floor 55%, repo baseline tracked per PR) plus `flutter analyze` and `dart format` checks
- Integration tests live in [`integration_test/`](integration_test)

CI workflows: [`ci.yml`](.github/workflows/ci.yml) (tests, analyze, coverage), [`docs.yml`](.github/workflows/docs.yml), [`release.yml`](.github/workflows/release.yml).

---

## 📚 Documentation

A VitePress documentation site lives in [`docs/`](docs):

- [`docs/guide/introduction.md`](docs/guide/introduction.md) — concepts & overview
- [`docs/guide/getting-started.md`](docs/guide/getting-started.md) — setup walkthrough
- [`docs/plugins/overview.md`](docs/plugins/overview.md) — plugin system deep-dive
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — internals
- [`docs/SECURITY.md`](docs/SECURITY.md) · [`docs/TESTING.md`](docs/TESTING.md) · [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md)
- [`docs/angular-integration.md`](docs/angular-integration.md) — Angular-specific guide

Every plugin additionally ships its own README under `lib/plugins/<plugin>/README.md` — these are the authoritative API references and are kept in sync with the Dart sources.

---

## 🤝 Contributing

1. Create a plugin or fix in a feature branch.
2. Add/extend tests — the coverage gate must pass.
3. Update the affected plugin README(s): every supported method, parameter, return shape, and event must be documented.
4. Run `flutter analyze`, `dart format .`, and `flutter test` before opening a PR.

---

## 📄 License

Sweetmelon is released under the [MIT License](License).
