# CLI overview

The `sweetmelon` CLI keeps a project consistent with `sweetmelon.yaml`: it switches plugins on and off, brings pubspec, permissions and titles in line with that choice, renames the app, generates icons and bumps versions.

It lives in the repository root and runs with Dart:

```bash
dart run bin/sweetmelon.dart <command> [options]
dart run bin/sweetmelon.dart --help
```

## What it is for

| Task | Command |
| --- | --- |
| See which plugins exist and which are on | `list`, `info <plugin>` |
| Turn plugins on or off | `plugin enable camera nfc`, `plugin disable nfc` |
| Apply the plugin choice to pubspec, permissions and the service locator | `sync --apply` |
| Check that everything matches `sweetmelon.yaml` (CI) | `sync --check` |
| Change the Android and iOS application id | `rename --id com.acme.app --apply` |
| Change the Dart package name | `rename --dart-package my_app --apply` |
| Generate all app icons from one image | `icon assets/icon.png --apply` |
| Bump the version | `bump patch --apply` |
| Health check | `doctor` |

## Safe by default

Commands that write files (`sync`, `rename`, `icon`, `bump`, `configure`) share one safe writer:

- **Dry run first.** Nothing is written unless you pass `--apply`.
- **Clean git required.** The command refuses to run with uncommitted changes (override with `--force`), so a change is always easy to review and revert.
- **Backup and rollback.** The previous files are copied to `.sweetmelon/backup/<timestamp>/`, and a failed write is rolled back.

## A typical flow

```bash
dart run bin/sweetmelon.dart plugin enable geolocation   # flip the switch in sweetmelon.yaml
dart run bin/sweetmelon.dart sync                        # preview the changes
dart run bin/sweetmelon.dart sync --apply                # service locator, pubspec, permissions
flutter pub get
```

See [Commands](/cli/commands) for every option and [Plugin manager](/cli/plugin-manager) for the plugin commands.
