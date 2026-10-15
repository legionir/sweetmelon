# Changelog

Sweetmelon core follows [Semantic Versioning](https://semver.org). An app
pins a core release in `sweetmelon.yaml` (`core: "2.4"`).

- **Patch** releases (`2.4.x`) only fix bugs. They never change behaviour, the
  JS bridge API or `sweetmelon.yaml`, so an app can take them safely.
- **Minor** releases (`2.5.0`) may add features and change generated output.
  An app moves to one on purpose, after reading this file.
- **Major** releases (`3.0.0`) may break the bridge or the config format.

Fixes for an older minor are made on its `release/x.y` branch and tagged there.

## [2.6.0]

AI on the device. Three plugins, off unless an app asks for them; the user
brings the models from their own files, nothing is downloaded by the core.

### Added
- **`modelManager`** keeps AI models in one folder of the app and imports them
  from the user's files: pick files or an archive (`.zip`, `.tar.gz`,
  `.tar.bz2`, `.tar.xz`), the plugin moves them in (instant, even for a
  multi-gigabyte model) and unpacks archives. `list`, `get`, `rename`,
  `remove`. Plugins that run models only open files inside that folder.
- **`llm`**: chat with a GGUF language model (llama.cpp through
  [llamadart](https://pub.dev/packages/llamadart)), with images when the model
  comes with a projector. The answer streams as `llm.token` events, then
  `llm.done`. Every sampling setting is a parameter: `temperature`, `topP`,
  `topK`, `minP`, `repeatPenalty`, `presencePenalty`, `maxTokens`, `seed`,
  `stop`, thinking budget; and load options: context size, threads, batch
  sizes, GPU layers, flash attention, KV cache type, mmap/mlock, chat template,
  RoPE.
- **`speechOffline`**: speech recognition (Whisper, SenseVoice, Paraformer,
  transducer) and speech synthesis (Piper/VITS, Kokoro) with
  [sherpa-onnx](https://pub.dev/packages/sherpa_onnx), in a worker isolate.
  Hold-to-talk: `startListening` / `stopListening` return the text. `speak`
  queues text, synthesises it while the previous one plays and plays it.
  Settings: language, task, threads, tail paddings, speaker, speed, noise
  scales, length scale, silence scale, volume.
- Contract tests (`test/unit/core`): the model store never leaves its folder
  (`..`, links), and the file-role detection for each model type.

### Changed
- Tests no longer hard-code the core minor (`core: "2.5"`), so a new minor
  does not break them.

## [2.5.3]

### Fixed
- **`simInfo` was always denied.** It requires the `phone` permission, which the
  permission provider did not know. `phone` (`READ_PHONE_STATE`) is mapped now.

### Added
- Contract tests (`test/unit/contract`): a plugin may not gate all of its
  methods behind a permission without being on a reviewed list, every declared
  permission must be one the provider can map, and the version in
  `core_version.dart`, `pubspec.yaml`, `sweetmelon.yaml`, the CHANGELOG and the
  documented `@v` pins must agree.

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
