# Quick Start

## 1. Setup

```bash
# Clone or create project
dart run bin/sweetmelon.dart create project my_app
cd my_app

# Configure plugins
dart run bin/sweetmelon.dart configure

# Install dependencies
flutter pub get
```

## 2. Place your HTML app

```
assets/www/
  index.html     ← your app entry point
  css/
  js/
    native-sdk.js  ← copy from Sweetmelon
    app.js
```

## 3. Use in JavaScript

```html
<script src="js/native-sdk.js"></script>
<script>
  NativeSDK.waitForReady().then(async () => {
    // Device info
    const { device } = await NativeSDK.deviceInfo.getAll();
    console.log('Running on:', device.model);

    // Storage
    await NativeSDK.storage.set('user', { name: 'Ali' });
    const user = await NativeSDK.storage.get('user');

    // Listen to events
    NativeSDK.on('connectivity.change', (data) => {
      console.log('Online:', data.online);
    });
  });
</script>
```

## 4. Run

```bash
flutter run
```

## Plugin CLI

```bash
# List all plugins
dart run bin/sweetmelon.dart list

# Enable plugins
dart run bin/sweetmelon.dart plugin enable camera bluetooth

# Disable plugins
dart run bin/sweetmelon.dart plugin disable nfc

# Apply changes
dart run bin/sweetmelon.dart configure

# Health check
dart run bin/sweetmelon.dart doctor
```

## Angular Integration

```bash
# Build your Angular app
ng build --configuration production \
  --output-path /path/to/assets/www \
  --base-href ./

# Run Flutter
flutter run
```
