# Testing

## Commands

Run from the repository root.

```bash
flutter pub get
flutter analyze --fatal-warnings                       # analyzer (CI)
bash .github/scripts/format_report.sh                  # dart format check (CI)
flutter test test/ --coverage --reporter expanded      # all Dart tests (CI)
python3 .github/scripts/coverage_gate.py coverage/lcov.info 55 '(^|/)(gen|generated)/|\.g\.dart$'
node --test test/js/bridge_sdk.test.mjs                # injected SDK (CI)
flutter test integration_test/app_test.dart -d <android-device-id>   # on-device E2E (CI, emulator)
```

`flutter test test/` runs every directory under `test/`: unit, security,
regression, integration and performance. Helpers in `test/helpers/` are not
test files.

## CI jobs

`.github/workflows/ci.yml`, triggered on push to `main` and `arena/**`, on pull
requests, and manually.

| Job | What it runs |
| --- | --- |
| Analyze, unit, security and regression tests | `flutter analyze --fatal-warnings`; `flutter test test/ --coverage`; coverage gate; format check; coverage upload |
| Injected JavaScript SDK (Node VM) | `node --test test/js/bridge_sdk.test.mjs` |
| Android build (debug and release) | `flutter build apk --debug` and `--release` (release is unsigned without the signing variables) |
| Android end-to-end (emulator) | `integration_test/app_test.dart` on an API 33 x86_64 emulator, through `.github/scripts/run_e2e.sh` |
| iOS build (macOS, no codesign) | `flutter pub get`; `flutter config --no-enable-swift-package-manager`; `ios_permissions.py ios/Podfile`; `flutter build ios --config-only --no-codesign`; `pod install`; `flutter build ios --debug --no-codesign` |

Every job must pass for a change to be considered verified. When `GITHUB_TOKEN` is
available, the format check also publishes each unformatted file's diff as a check run
before it fails.

### Coverage gate

The gate enforces a minimum line-coverage percentage over the files in `lcov`
output, excluding generated code. The default is 55 %. The threshold can be
overridden with the repository variable `COVERAGE_MIN`. Any change to it must be
recorded in `docs/WORKLOG.md` with the reason.

### E2E result contract

`run_e2e.sh` writes `e2e.txt` and `e2e.rc` on every exit path. The job passes
only when the test exits with code 0, the output contains no failure markers,
and exactly two `E2E_OK:` markers were printed (one per on-device test).

## What is covered

| Area | File | What it checks |
| --- | --- | --- |
| Protocol | `test/unit/protocol_test.dart` | identifier rules, request and batch validation, batch size and timeout limits, stable error codes, error JSON without stack traces |
| Navigation | `test/unit/navigation_policy_test.dart` | allow-list, http blocked unless enabled, sub-frames checked, case-insensitive host match (SEC-001) |
| Storage paths | `test/unit/storage_path_test.dart` | path syntax, length and depth limits, traversal reported as SANDBOX_VIOLATION (SEC-002) |
| Guards, cache, rate limit, permissions | `test/unit/security_units_test.dart` | rate-limit window and per-key rules, bounded tracked keys (SEC-008), LRU eviction, TTL, cache copies (PERF-001), permission cache TTL (SEC-005), guard timeouts and duplicate ids, geolocation accuracy and timeout rules (BUG-013) |
| Bridge | `test/unit/message_bridge_test.dart` | session tokens, token checks (SEC-004), size limit, stale-session responses dropped (SM-006), bounded pre-ready queue (BUG-003), event name and payload encoding (BUG-004), dispose stops delivery |
| Engine | `test/unit/plugin_manager_test.dart` | pipeline order, permissions (PERM-001), error contract (SEC-003), unknown methods (SM-005), maxConcurrentCalls and timeouts (SM-002, SM-004), read cache and write invalidation (BUG-001), batch order and timeouts (BUG-002), sequential stopOnError (BUG-007), activeCalls and error stats (STAT-001), traces, registry, dispose |
| Plugin validation | `test/unit/camera_validation_test.dart` | camera argument rules (BUG-009) |
| Geolocation lifecycle | `test/unit/geolocation_lifecycle_test.dart` | watch IDs and events (BUG-005), clearWatch, stream errors and the watch limit (SM-009), dispose of all watches (SM-011) |
| Debug inspector | `test/unit/devtools_redaction_test.dart` | `args` and `data` are redacted; input is not mutated (SEC-007) |
| Storage security | `test/security/storage_security_test.dart` | traversal, symlink escape, size limits, invalid base64, round trips, end-to-end through the engine |
| Regression: batches | `test/regression/batch_stop_on_error_test.dart` | BUG-007: sequential stopOnError sends CANCELLED to later items; parallel batches documented as not stopping; a timed-out sequential batch dispatches nothing later |
| Regression: camera cancel | `test/regression/camera_cancel_test.dart` | BUG-008: picker cancellation returns CANCELLED, is not counted as an execution error, and leaves no in-flight state |
| Regression: WebView lifecycle | `test/regression/webview_lifecycle_test.dart` | BUG-011: detach ends the session; no script after detach; late callbacks of a superseded host cannot change the live session; repeated detach is safe |
| Regression: camera concurrency | `test/regression/camera_concurrency_test.dart` | CONC-001: while one camera call is open, a second is refused with RATE_LIMIT_EXCEEDED before the picker opens; the slot is free again after release |
| Regression: argument validation | `test/regression/argument_validation_test.dart` | BUG-009: invalid camera and geolocation arguments return INVALID_ARGS before the plugin runs; a valid control call reaches the plugin |
| Integration | `test/integration/bridge_pipeline_test.dart` | JSON messages through the real bridge and engine: round trip, forged token dropped, unknown plugin, malformed and oversized input, batch envelope |
| Performance smoke | `test/performance/perf_smoke_test.dart` | 500 bridge round trips, 1000 ordered events, 10k cache operations on a 1k-entry cache within generous budgets; overwrite does not evict other entries (PERF-001) |
| Injected SDK | `test/js/bridge_sdk.test.mjs` | the shipped SDK template run in a Node VM: install rules, iframe refusal, token in every message, call and batch resolution, batch error and timeout (BUG-002), errors, events, listener isolation |
| Device | `integration_test/app_test.dart` | app boots into the WebView host; storage round-trip through the real engine with traversal rejected |

Test names reference finding IDs where the test is about that finding. The
regression files are the exception: each one names its finding in the file
header. The BUG-007, BUG-008, BUG-009 and BUG-011 files also name it in their
group name; `camera_concurrency_test.dart` names CONC-001 in the header only.

## What is not covered

- **JavaScript through the real WebView.** No automated test runs the page's
  JavaScript inside the WebView. The Node VM tests cover the SDK code, the
  bridge unit tests cover the protocol, and the device test calls the engine
  directly.
- **`WebViewHost` widget itself.** The lifecycle decisions are in
  `BridgeAttachment`, which is tested against the real `MessageBridge`. The
  widget's callbacks are not driven by a test, because that needs a WebView
  platform implementation in the test environment.
- **Camera and geolocation hardware paths.** Picker success results and
  position streams from the OS are not exercised; only cancellation, empty
  results, the watch lifecycle with an injected stream, and argument validation
  are tested.
- **iOS runtime.** The iOS job builds the app without code signing. It does not
  run the app on a simulator or device.

## Adding a test

- Put unit tests in `test/unit/` for the area they cover, or in `test/security/`
  when the input is attacker-controlled.
- For a bug fix, add a regression test in `test/regression/` that names the
  finding ID, and check that it fails before the fix when practical.
- Use `test/helpers/fakes.dart` for plugins, permission providers, clocks, the
  script recorder and the engine harness, and `test/helpers/picker_fakes.dart`
  for the image picker.
