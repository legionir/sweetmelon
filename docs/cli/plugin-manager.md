# Plugin manager

Plugins are switched in `sweetmelon.yaml`; the plugin commands edit that file for you.

```bash
dart run bin/sweetmelon.dart list                   # all plugins and their status
dart run bin/sweetmelon.dart info camera            # details of one plugin
dart run bin/sweetmelon.dart plugin enable camera bluetooth
dart run bin/sweetmelon.dart plugin disable nfc
dart run bin/sweetmelon.dart plugin generate MyPlugin
```

`enable` and `disable` only change the `enabled:` flag of the named plugins. They do not touch any other file; run `sync --apply` afterwards (and `flutter pub get`) to apply the choice:

```bash
dart run bin/sweetmelon.dart plugin enable nfc
dart run bin/sweetmelon.dart sync --apply
flutter pub get
```

`sync` registers the plugin in the service locator, adds its pubspec dependencies, and adds the permissions it needs. Disabling a plugin removes them again, while the plugin's source and tests stay in the repository so it can be switched back on at any time.

## Generating a new plugin

`plugin generate MyPlugin` scaffolds `lib/plugins/my_plugin/` (plugin class, `pubspec.yaml`, README) and a test in `test/plugins/my_plugin_plugin_test.dart`. See [Plugin development](/advanced/plugin-development).

## Checking the result

```bash
dart run bin/sweetmelon.dart doctor        # reports e.g. plugins that are disabled but still imported
dart run bin/sweetmelon.dart sync --check  # CI: fails when files differ from sweetmelon.yaml
```
