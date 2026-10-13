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
- adds or removes the Android permissions, Android features and iOS usage descriptions each plugin needs (every plugin has an entry; manifest components such as intent filters and services, and non-string `Info.plist` values such as `UIBackgroundModes`, are not managed);
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

## prepare

Takes a fresh checkout to a buildable project in one step.

```bash
dart run bin/sweetmelon.dart prepare --www my_www \
  --package-name com.acme.app --dart-package my_app \
  --app-name "My App" --icon icon.png --apply
```

Order: check `core:` -> validate the values -> copy `--www` into `assets/www`
(the bridge files come from the core) -> choose plugins (`plugin_selection`) ->
write the values back to `sweetmelon.yaml` -> rename the Android package and the
Dart package -> icon -> `sync`. Running it twice changes nothing the second time.
A value on the command line wins over `sweetmelon.yaml`. Without `--apply` it
prints the plan. Run `flutter pub get` afterwards (the CLI itself lives in the
renamed package). `--strict` fails on bridge calls that `detect` cannot resolve.

## detect

Lists the plugins a web app uses.

```bash
dart run bin/sweetmelon.dart detect --www www [--strict]
```

It reads text: `NativeSDK.camera.x()`, a variable holding `NativeSDK`,
`const { camera } = NativeSDK`, `plugin: 'camera'`, `call('camera', ...)` and the
annotation `// sweetmelon:uses camera`. A plugin name built at run time is
reported with its line: a warning, or exit 1 with `--strict`.

## init

```bash
dart run bin/sweetmelon.dart init ../my-app --package-name com.acme.app --app-name "My App" --apply
```

Writes a new app folder (`www/`, `sweetmelon.yaml`, a build workflow pinned to this
core version). The folder must be empty.

## upgrade

```bash
dart run bin/sweetmelon.dart upgrade --to 2.4.1 --apply
```

Sets `core:` and the `legionir/sweetmelon@v...` pins in `.github/workflows`. The
version is exact. A new minor needs `--allow-minor`, a new major `--allow-major`.

## Global options

| Option | Meaning |
| --- | --- |
| `--apply` | Write the changes (default is a dry run) |
| `--check` | `sync` only: write nothing, exit 1 when files are out of date |
| `--force` | Write even when git has uncommitted changes |
| `-h`, `--help` | Show help |
| `-v`, `--version` | Show the CLI version |
