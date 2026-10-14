# Changelog

Sweetmelon core follows [Semantic Versioning](https://semver.org). An app
pins a core release in `sweetmelon.yaml` (`core: "2.4"`).

- **Patch** releases (`2.4.x`) only fix bugs. They never change behaviour, the
  JS bridge API or `sweetmelon.yaml`, so an app can take them safely.
- **Minor** releases (`2.5.0`) may add features and change generated output.
  An app moves to one on purpose, after reading this file.
- **Major** releases (`3.0.0`) may break the bridge or the config format.

Fixes for an older minor are made on its `release/x.y` branch and tagged there.

## [2.5.2]

`v2.5.1` was tagged by hand without a code change; this is the release that
carries the fixes below.

### Fixed
- **The hardware volume keys did nothing in every app.** `MainActivity`
  swallowed `KEYCODE_VOLUME_UP/DOWN` even when no one was listening. It now
  keeps them only while the `volume_buttons` plugin is listening.

## [2.5.0]

### Added
- **`fileSystem.browse`**: read-only listing of the device's shared storage
  (Music, Download, SD card), one folder per call, so an app can show a file
  manager. Needs the `storage` / `audio` permission, writes nothing.
- `audio` permission name for `NativeSDK.permission.*` (`READ_MEDIA_AUDIO`).

### Changed
- The WebView no longer allows pinch zoom (`enableZoom(false)`), so an app
  cannot open zoomed in or be zoomed by accident.

### Fixed
- **`audio.play` failed until the microphone was granted.** The plugin
  declared `microphone` as required for every call, so playback was rejected
  with "Permission microphone denied". Only `startRecording` needs it now.

## [2.4.2]

### Fixed
- **Audio plugin build.** `record` is now `^6.2.1` (was `^5.1.2`). With 5.x, pub
  paired `record_linux 0.7.2` with `record_platform_interface 1.6.0` and the
  Flutter compile failed (`RecordLinux` missing `startStream`).

## [2.4.0]

First versioned release.

### Added
- **Versioning.** `core:` key in `sweetmelon.yaml`; `validate`, `doctor` and
  `prepare` refuse a project built for another minor. `sweetmelon --version`
  prints the core version (`lib/core_version.dart`). The release workflow
  checks the tag against it and publishes this file's section as notes.
- **GitHub Action** (`uses: legionir/sweetmelon@v2.4.0`): builds an APK, AAB or
  unsigned iOS app from a `www` folder and a `sweetmelon.yaml`, with signing from
  repository secrets.
- `sweetmelon prepare`: injects `www`, selects plugins, sets package name, Dart
  package, app name and icon, then syncs. Idempotent.
- `sweetmelon detect` and `plugin_selection` (`mode: auto|manual`, `include`,
  `exclude`).
- `sweetmelon init` (new app folder) and `sweetmelon upgrade` (move to another
  core release).
- `project.dart_package` and `project.icon` in `sweetmelon.yaml`.
- Build workflow inputs: app name, and checkboxes for APK, AAB and iOS.

### Fixed
- `sync` after `rename --dart-package` no longer writes `package:sweetmelon/`
  imports into the service locator, and plugin imports are found under the
  renamed package.
