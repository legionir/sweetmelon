# 🚀 Sweetmelon Release Checklist

## Pre-Release

### Code Quality
- [ ] All tests pass: `flutter test`
- [ ] No analyzer warnings: `flutter analyze`
- [ ] Code formatted: `dart format .`
- [ ] Coverage > 80%: `flutter test --coverage`

### Configuration
- [ ] `sweetmelon.yaml` reviewed and correct
- [ ] Only necessary plugins enabled
- [ ] `dart run bin/sweetmelon.dart validate` passes
- [ ] `dart run bin/sweetmelon.dart doctor` passes

### Security
- [ ] `dart run bin/sweetmelon.dart security-audit` passes
- [ ] Debug logging disabled in release
- [ ] `android:debuggable` NOT in manifest
- [ ] SSL pinning configured for production APIs
- [ ] ProGuard rules verified: `android/app/proguard-rules.pro`
- [ ] Cleartext traffic restricted to localhost only
- [ ] Sensitive data uses `secureStorage` plugin
- [ ] Root detection implemented if handling sensitive data

### Performance
- [ ] Performance audit run and reviewed
- [ ] Unnecessary plugins disabled
- [ ] Cache configured appropriately
- [ ] Large images compressed

### Firebase
- [ ] `google-services.json` is production version
- [ ] Firebase Analytics enabled
- [ ] Crashlytics enabled
- [ ] Remote Config default values set

### Android
- [ ] `minSdk` ≥ 21
- [ ] `targetSdk` = latest stable
- [ ] Signing keystore backed up securely
- [ ] `key.properties` NOT committed to git
- [ ] Version code incremented
- [ ] Version name updated

### Assets
- [ ] `assets/www/` contains production build
- [ ] Production Angular/React/Vue build used
- [ ] No development tools in www/
- [ ] `native-sdk.js` is latest version
- [ ] Console.log statements removed from JS

### Testing
- [ ] Tested on physical Android device
- [ ] Tested on minimum API device (API 21)
- [ ] Tested offline mode
- [ ] Tested all critical user flows
- [ ] Tested push notifications
- [ ] Tested deep links
- [ ] Camera, microphone, location tested

## Build

```bash
# 1. Clean
flutter clean
flutter pub get

# 2. Run tests
flutter test

# 3. Build APK for testing
flutter build apk --release --split-per-abi

# 4. Build App Bundle for Play Store
flutter build appbundle --release

# 5. Verify APK
apksigner verify build/app/outputs/flutter-apk/app-release.apk
```

## Play Store Upload

- [ ] App Bundle uploaded to Play Console
- [ ] Release notes added in all supported languages
- [ ] Screenshots updated if UI changed
- [ ] Privacy policy URL correct
- [ ] Content rating current
- [ ] Rollout percentage set (10% → 50% → 100%)

## Post-Release

- [ ] Monitor Crashlytics for 24 hours
- [ ] Monitor Firebase Analytics for anomalies
- [ ] Check Play Store reviews
- [ ] Tag release in Git: `git tag v1.x.x && git push --tags`
- [ ] Update CHANGELOG.md
- [ ] Notify team

## Rollback Plan

If critical issue found:
1. Halt rollout in Play Console immediately
2. Fix issue in hotfix branch
3. Re-run full checklist
4. Re-release
