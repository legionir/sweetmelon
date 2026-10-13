# Android builds

## Local build

```bash
flutter build apk --release --target-platform android-arm,android-arm64
```

The release build is signed from environment variables, never from a committed key. Without a keystore the release APK stays unsigned:

```bash
export SWEETMELON_KEYSTORE_PATH=release.jks        # relative to android/app
export SWEETMELON_KEYSTORE_PASSWORD=...
export SWEETMELON_KEY_ALIAS=...
export SWEETMELON_KEY_PASSWORD=...
```

## Build in CI

The workflow **Build Android APK (Manual)** (`.github/workflows/build-apk.yml`) builds a signed ARM APK on demand: open the *Actions* tab, choose the workflow and press *Run workflow*. It checks that the generated files match `sweetmelon.yaml`, signs with a throw-away key created for that run, and uploads the artifact `sweetmelon-universal-apk` for 14 days.

The throw-away key is fine for testing. **For store releases, sign with your own keystore.**

## Before you ship

Change the application id (`rename --id com.yourcompany.app --apply`), set `project.display_name` and the version, and generate your icons with `icon`. The [release checklist](/RELEASE_CHECKLIST) lists the rest.
