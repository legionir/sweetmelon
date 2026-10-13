# Getting Started

## Prerequisites

- Flutter SDK 3.0+
- Android Studio / VS Code
- Node.js 18+ (for web app build)
- Android device or emulator (API 21+)

## Step 1: Create Project

```bash
# Option A: Use CLI
dart run bin/sweetmelon.dart create project my_app
cd my_app

# Option B: Manual
flutter create --org com.example my_app
cd my_app
# Copy Sweetmelon files...
```

**Option C: Depend on the core as a package** (recommended for applications that keep their own repository, such as [MelonAI Studio](https://github.com/legionir/sweet-melon-ai-client)):

```yaml
# pubspec.yaml
dependencies:
  sweetmelon:
    git:
      url: https://github.com/legionir/sweetmelon.git
      ref: main   # pin a tag or commit for reproducible builds
```

Your app then owns `lib/main.dart`, `lib/di/service_locator.dart` (copy the one from the core as a template and import everything from `package:sweetmelon/...`), `assets/www`, and the `android/` and `ios/` projects. Add the Flutter packages and the Android/iOS permissions of every plugin you enable to the app itself, and copy `native-sdk.js`, `native-sdk.d.ts` and `native-resilience.js` from the core's `assets/www/js` into the app's `assets/www/js`. The `sweetmelon` CLI is meant for a project that vendors the core (Options A and B); an app using Option C manages its plugin list directly.

## Step 2: Configure Plugins

Edit `sweetmelon.yaml`:

```yaml
plugins:
  permission:
    enabled: true
  storage:
    enabled: true
  http:
    enabled: true
  # ... enable what you need
```

Apply configuration:

```bash
dart run bin/sweetmelon.dart configure
```

## Step 3: Add Your Web App

Place your built web app in `assets/www/`:

```bash
# Angular
ng build --configuration production \
  --output-path assets/www \
  --base-href ./

# React
GENERATE_SOURCEMAP=false npm run build
cp -r build/* assets/www/

# Vue
npm run build
cp -r dist/* assets/www/

# Vanilla HTML
# Just put files in assets/www/
```

**Important:** Include `native-sdk.js` in your HTML:

```html
<script src="js/native-sdk.js"></script>
```

## Step 4: Use NativeSDK

```javascript
// Wait for bridge to be ready
await NativeSDK.waitForReady();

// Now use any plugin
const info = await NativeSDK.deviceInfo.getAll();
console.log('Device:', info.device.model);

// Store data
await NativeSDK.storage.set('user', { name: 'Ali' });

// Listen to events
NativeSDK.on('connectivity.change', (data) => {
  console.log('Online:', data.online);
});
```

## Step 5: Run

```bash
flutter run
```

## Next Steps

- [Configuration →](https://github.com/legionir/sweetmelon/blob/main/sweetmelon.yaml)
- [Browse all 104 plugins →](/plugins/overview)
- [Angular integration →](/angular-integration)
- [Security guide →](/SECURITY)
