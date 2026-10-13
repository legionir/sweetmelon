# Changelog

Sweetmelon core follows [Semantic Versioning](https://semver.org). An app
pins a core release in `sweetmelon.yaml` (`core: "2.4"`).

- **Patch** releases (`2.4.x`) only fix bugs. They never change behaviour, the
  JS bridge API or `sweetmelon.yaml`, so an app can take them safely.
- **Minor** releases (`2.5.0`) may add features and change generated output.
  An app moves to one on purpose, after reading this file.
- **Major** releases (`3.0.0`) may break the bridge or the config format.

Fixes for an older minor are made on its `release/x.y` branch and tagged there.

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
