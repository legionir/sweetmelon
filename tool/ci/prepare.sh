#!/usr/bin/env bash
# Runs "sweetmelon prepare" in the current project folder, then flutter pub get.
# Inputs come from the environment (empty keeps the value from sweetmelon.yaml):
#   IN_PACKAGE_NAME IN_DART_PACKAGE IN_APP_NAME IN_ICON IN_WWW IN_STRICT
set -euo pipefail

flutter pub get
ARGS=(--apply)
[ -n "${IN_PACKAGE_NAME:-}" ] && ARGS+=(--package-name "$IN_PACKAGE_NAME")
[ -n "${IN_DART_PACKAGE:-}" ] && ARGS+=(--dart-package "$IN_DART_PACKAGE")
[ -n "${IN_APP_NAME:-}" ] && ARGS+=(--app-name "$IN_APP_NAME")
[ -n "${IN_ICON:-}" ] && ARGS+=(--icon "$IN_ICON")
[ -n "${IN_WWW:-}" ] && ARGS+=(--www "$IN_WWW")
[ "${IN_STRICT:-false}" = "true" ] && ARGS+=(--strict)
dart run bin/sweetmelon.dart prepare "${ARGS[@]}"
flutter pub get
