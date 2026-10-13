# Configuration

Everything that depends on which plugins you use is controlled by one file, `sweetmelon.yaml`, in the project root.

```yaml
project:
  name: sweetmelon          # project name
  display_name: Sweetmelon  # app name and web titles
  version: 2.4.0            # version name (the build number lives in pubspec.yaml)
  min_sdk: "3.0.0"
  application_id: com.acme.app   # optional, used by `rename`
  www_path: assets/www      # your web app
  entry_point: index.html

plugins:
  storage:
    enabled: true
  camera:
    enabled: true
  nfc:
    enabled: false
```

| Key | Meaning |
| --- | --- |
| `project.display_name` | App label on Android/iOS and the title in `web/` and `assets/www/index.html` |
| `project.version` | Version name, written to the pubspec version by `sync` |
| `project.application_id` | Target for `rename` when no `--id` is given |
| `project.www_path`, `entry_point` | Where the bundled web app lives and which file loads first |
| `plugins.<name>.enabled` | Whether the plugin is registered and built into the app |

A plugin missing from the file counts as enabled.

## From the file to the project

```bash
dart run bin/sweetmelon.dart plugin enable camera   # or edit the file by hand
dart run bin/sweetmelon.dart sync --apply
flutter pub get
```

`sync` updates `service_locator.dart`, the pubspec dependencies, Android permissions, iOS usage descriptions, the analyzer exclusions and the app name. `sync --check` fails when any of these differ from the yaml, which is how CI keeps them honest. See [CLI commands](/cli/commands).

## Applications that depend on the core

An application that consumes `sweetmelon` as a package does not use `sync`. It registers its plugins in its own `lib/di/service_locator.dart`, declares the plugin packages it needs in its pubspec, and adds the permissions to its own manifests.
