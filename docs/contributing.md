# Contributing

1. Make your change in a feature branch.
2. Add or extend tests; the CI coverage gate must pass.
3. Update the README of every affected plugin: each supported method, parameter, return shape and event must be documented.
4. Run `flutter analyze`, `dart format .` and `flutter test` before opening a pull request.
5. If you touch `sweetmelon.yaml` or the plugin set, run `dart run bin/sweetmelon.dart sync --apply` (CI runs `sync --check`).

See [Testing](/TESTING) for how the test suites are organized and [Release checklist](/RELEASE_CHECKLIST) for releases.
