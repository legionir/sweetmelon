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
- `core:` key in `sweetmelon.yaml`; `validate` and `doctor` refuse a project
  built for another minor.
- `project.dart_package`, `project.icon` and the `plugin_selection:` section
  (`mode`, `include`, `exclude`) in `sweetmelon.yaml`.
- `sweetmelon --version` prints the core version (`lib/core_version.dart`).
