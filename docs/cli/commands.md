# Commands

Run any command as `dart run bin/sweetmelon.dart <command>`.

| Command | What it does |
| --- | --- |
| `create` | Scaffold a new Sweetmelon project or component |
| `plugin` | `generate`, `enable`, `disable`, `list`, `info` (see [Plugin manager](/cli/plugin-manager)) |
| `list` | List all available plugins and whether they are enabled |
| `info <plugin>` | Show details of one plugin |
| `configure` | Process `sweetmelon.yaml` and regenerate `service_locator.dart` |
| `validate` | Validate `sweetmelon.yaml` and project files |
| `sync` | Bring pubspec, permissions, app name and web titles in line with `sweetmelon.yaml` |
| `rename` | Change the application id or the Dart package name |
| `icon` | Generate Android, iOS and web icons from a square PNG |
| `bump` | Bump the version |
| `build` | Build the `www` assets for deployment |
| `clean` | Clean generated files and cache |
| `doctor` | Check project health and dependencies (exit code 1 on failure) |

## sync

```bash
dart run bin/sweetmelon.dart sync            # preview
dart run bin/sweetmelon.dart sync --apply    # write
dart run bin/sweetmelon.dart sync --check    # exit 1 when files are out of date (CI)
```

`sync` treats `sweetmelon.yaml` as the single source of truth. It:

- registers only the enabled plugins in `lib/di/service_locator.dart`;
- **adds** the pubspec dependencies of enabled plugins that are not declared yet (plain version constraints from the plugin's own `pubspec.yaml`; entries you already have are never changed) and **removes** the unused ones of disabled plugins;
- adds or removes the Android permissions and iOS usage descriptions each plugin needs;
- keeps the analyzer exclusions and the list of test targets in step with the disabled plugins;
- sets the app name and the web titles from `project.display_name`, and the version name from `project.version`.

Run `flutter pub get` afterwards.

## rename

```bash
dart run bin/sweetmelon.dart rename --id com.acme.app --apply
dart run bin/sweetmelon.dart rename --dart-package my_app --apply
```

- `--id` changes the Android `applicationId` and the iOS bundle id in the native files and moves `MainActivity.kt` to the new package folder.
- `--dart-package` changes `name:` in `pubspec.yaml`, the dependency key in the plugin pubspecs and every `package:<old>/` import in `lib`, `test`, `integration_test`, `bin` and `tool`. Run `flutter pub get` afterwards. Without `--id`, the native ids stay as they are.

## icon

```bash
dart run bin/sweetmelon.dart icon assets/icon.png --apply
```

Takes a square PNG of 1024 px or more and writes every Android, iOS and web icon size into the app. iOS icons are flattened onto white because they must not have transparency.

## bump

```bash
dart run bin/sweetmelon.dart bump build|patch|minor|major --apply
```

The version name lives in `project.version` (`sweetmelon.yaml`); the build number is the `+n` part of the pubspec version. Both are written together.

## Global options

| Option | Meaning |
| --- | --- |
| `--apply` | Write the changes (default is a dry run) |
| `--check` | `sync` only: write nothing, exit 1 when files are out of date |
| `--force` | Write even when git has uncommitted changes |
| `-h`, `--help` | Show help |
| `-v`, `--version` | Show the CLI version |
