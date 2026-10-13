# Installation

## Requirements

- Flutter 3.x with Dart 3 or newer
- Android SDK (the primary platform) and/or Xcode for iOS
- Node.js 18+ only if your web app has a build step

## Use the core as a package (recommended)

Applications keep their own web UI and native projects and depend on the core:

```yaml
# pubspec.yaml
dependencies:
  sweetmelon:
    git:
      url: https://github.com/legionir/sweetmelon.git
      ref: main   # pin a tag or commit for reproducible builds
```

See [Getting started](/guide/getting-started), Option C, for what the app owns.

## Clone the repository

To try the bridge, or to start a project that vendors the core:

```bash
git clone https://github.com/legionir/sweetmelon.git
cd sweetmelon
flutter pub get
flutter run
```

This runs the default **Native Bridge Test Suite** from `assets/www`.

## Verify the toolchain

```bash
flutter doctor
dart run bin/sweetmelon.dart doctor
```
