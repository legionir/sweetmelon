# Sweet-Melon — Audit Execution Plan

Status legend: `[ ]` Not Started · `[~]` In Progress · `[x]` Completed ·
`[-]` Not Applicable · `[!]` Blocked (only for real external constraints).

Convention for `[-]`: reserved for an item that does not apply to this repository,
with the reason written next to it. It is never used for unfinished, deferred or
unverified work. No item in this plan uses `[-]`.

Definition of Done for a finding: problem identified, root cause identified,
implementation fixed, tests added and passing, regression protected,
documentation updated, plan updated, worklog updated.

---

## 1. Executive Summary

Sweet-Melon is a Flutter application that exposes Android/iOS native
capabilities (camera, storage, geolocation) to JavaScript running inside a
`webview_flutter` WebView through a message bridge.

The initial audit found that the repository was a prototype: no tests, no CI,
no `.gitignore`, and several security and correctness gaps on the most
sensitive path (JavaScript → native). The most serious issues were:

- the native bridge was reachable from every frame and from any navigated
  origin (SEC-001);
- a path traversal in the storage plugin (`listFiles`) (SEC-002);
- cached write operations returning stale or skipped writes (BUG-001);
- permissions implicitly granted and capabilities that were only metadata
  (SEC-005, ARCH-002).

This pass fixes the P0/P1 items, adds unit, integration, security, regression,
JavaScript-SDK and (on Android) end-to-end tests, adds a CI workflow, and
documents the real behaviour. Items that cannot be verified from this sandbox
would be recorded as `[!]` with the concrete reason in section 15. None remain.

## 2. Repository Overview

| Path | Purpose |
| --- | --- |
| `lib/main.dart`, `lib/app.dart` | Application entry point |
| `lib/di/service_locator.dart` | Composition root (get_it) |
| `lib/screens/home_screen.dart` | Demo screen + demo JavaScript page |
| `lib/packages/core` | Protocol, bridge, WebView host, logger |
| `lib/packages/plugin_engine` | Plugin contract, registry, manager pipeline |
| `lib/packages/security` | Execution guard, rate limiter, permissions, sandbox path |
| `lib/packages/performance` | LRU/TTL cache |
| `lib/packages/devtools` | Bridge inspector (debug only) |
| `lib/plugins/{camera,storage,geolocation}` | Native plugins |
| `android/`, `ios/`, `web/` | Platform projects (web is the Flutter default and is not a bridge target) |
| `test/` | Unit, integration, security, regression tests (Dart) and `test/js` (SDK) |
| `integration_test/` | End-to-end test on a real Android WebView |
| `docs/` | Plan, worklog, architecture, security, testing docs |

Layout note (ARCH-001): the in-tree "packages" are not separate pub packages.
Their unused nested `pubspec.yaml` files were removed; everything is one
package `sweetmelon` and is imported as `package:sweetmelon/packages/...`.

## 3. Architecture Overview

```
JavaScript (page)            window.Native.call / batch / on
    │  JSON string, token     flutterBridge.postMessage
    ▼
WebViewHost (runtime)        channel → size limit → NavigationPolicy (for loads)
    ▼
MessageBridge (core)         session token check → protocol parse → dispatch
    ▼
PluginManager (engine)       resolve → method/capability → rate limit →
    │                        permission → validate args → cache → concurrency
    │                        → ExecutionGuard (timeout) → plugin.onCall
    ▼
Plugin (camera/storage/geo)  SandboxPath · PlatformPermission · platform APIs
    ▼
Native Android/iOS APIs
    ▲
PluginResponse / Event       window.__resolveCall / __resolveBatch / __emitEvent
    │
JavaScript                   promise settled / listener invoked
```

See `docs/ARCHITECTURE.md` for the full description.

## 4. Current State (before this pass)

- Dart: ~4.4k lines, 0 tests, analyzer never run in repo.
- Android: builds configured, release signed with debug key, duplicate MainActivity.
- iOS: project present; no Podfile in repository; no usage descriptions.
- CI: none. Documentation: README empty.

## 5. Findings

Priority: P0 critical · P1 high · P2 medium · P3 low · P4 improvement.

### Security

- [x] **SEC-001 (P0)** JavaScript trust boundary. The `flutterBridge` channel
  was exposed to all frames; any page could post requests; navigation to any
  origin was allowed when `allowedHosts` was empty; non-HTTP schemes were not
  filtered. Fix: `NavigationPolicy` (default deny remote, block non-http(s)
  schemes), SDK installed only in the top frame, per-session random token that
  every message must carry (constant-time compare), tokens invalidated on every
  page start.
- [x] **SEC-002 (P0)** Storage path traversal. `listFiles` skipped `..`
  validation and only compared strings; no symlink containment anywhere. Fix:
  `SandboxPath` validates syntax (no absolute, no `..`, no NUL/backslash/colon),
  canonicalises the nearest existing ancestor and rejects symlinks.
- [x] **SEC-003 (P1)** Error disclosure. Responses contained `stackTrace` and
  raw `e.toString()` messages. Fix: unexpected exceptions return a generic
  message (`Internal error` in the bridge, `Plugin execution failed` in the
  manager; see 5b); stack traces are logged natively only.
- [x] **SEC-004 (P1)** No message size limit and no request-origin check on
  bridge input. Fix: 2 MiB limit, token check, strict protocol validation.
- [x] **SEC-005 (P1)** Implicit permission grants (`StaticPermissionProvider`
  granted camera/storage/location always) and permission cache that never
  expires. Fix: `PlatformPermissionProvider` (permission_handler + sandbox
  rules), 5 s TTL cache, explicit `permanentlyDenied` status returned to JS.
- [x] **SEC-006 (P1)** Android release build signed with the debug key.
  Fix: release signing read from environment; without it release is unsigned.
- [x] **SEC-007 (P2)** Debug inspector (shows every bridge payload) was shown in
  production. Fix: FAB and inspector only in debug builds (`kDebugMode`; see 5b).
- [x] **SEC-008 (P2)** Rate-limiter buckets keyed by untrusted names
  (unbounded growth). Fix: buckets only for registered plugin methods; idle
  buckets are pruned.
- [x] **SEC-009 (P2)** Unbounded storage read/write size. Fix: 5 MiB file limit.
- [x] **SEC-010 (P3)** Camera returns absolute temporary file paths to JS.
  Accepted and documented (needed for picker results); see `docs/SECURITY.md`.

### Bugs

- [x] **BUG-001 (P0)** Storage cache: `set`, `remove`, `writeFile`, `deleteFile`
  were cacheable (a second identical write was served from cache and never
  executed) and no mutation invalidated reads (stale data). Fix: read-only
  method declaration, invalidation of the plugin's cached reads on every
  successful mutation (key-prefix invalidation; see 5b).
- [x] **BUG-002 (P1)** Batch: an exception or malformed batch never resolved the
  JS promise; `options.timeout` ignored in JS. Fix: batch envelope validation,
  batch error response, per-item timeout, JS-side batch timeout.
- [x] **BUG-003 (P1)** Bridge `_isReady` was never reset on reload/navigation;
  responses for the previous page were sent into the new page; the pending
  script queue was unbounded. Fix: sessions (`startSession`/`endSession`),
  stale-session responses dropped, bounded queue.
- [x] **BUG-004 (P1)** `emitEvent` with a primitive payload produced invalid
  JS for the SDK (`JSON.parse` of a non-string); non-serialisable payloads threw.
  Fix: payload double-encoded; serialisation errors are logged and dropped.
- [x] **BUG-005 (P1)** Geolocation `watchPosition` discarded every position; only
  one watch; no event delivery. Fix: `watchId`-based watches, `geolocation.position`
  and `geolocation.error` events, `clearWatch({watchId})`, dispose cancels all.
- [x] **BUG-006 (P2)** Malformed requests: `json['requestId'] as String? ?? 'unknown'`
  could throw inside the error handler and answered a non-existent id. Fix:
  protocol validation with typed `ProtocolException`.
- [x] **BUG-007 (P2)** `stopOnError` ignored in parallel batches; missing results
  possible. Fix: every request gets a result; sequential stop emits `CANCELLED`
  for skipped items; documented limitation for parallel dispatch.
  Evidence: `test/regression/batch_stop_on_error_test.dart` (sequential CANCELLED,
  parallel limitation, timed-out batch dispatches nothing later), passed in CI
  run 37835701145 (commit `8b1fa1a`).
- [x] **BUG-008 (P1)** User cancellation of camera reported as `EXECUTION_ERROR`.
  Fix: `CANCELLED` error code. Decision: a user cancel is counted in `errorCount`
  (it produced no result), with code `CANCELLED`. Evidence:
  `test/regression/camera_cancel_test.dart`, passed in CI run 37835701145.
- [x] **BUG-009 (P1)** Argument casts in plugins threw `TypeError` and surfaced
  as `EXECUTION_ERROR`. Fix: validation before execution, `INVALID_ARGS` mapping.
- [x] **BUG-010 (P1)** Android manifest lacked CAMERA and location permissions;
  iOS lacked usage descriptions (plugins would fail or crash at runtime).
  Fix: manifest permissions and Info.plist usage strings.
- [x] **BUG-011 (P2)** WebView host never detached its controller from the bridge
  on dispose. Fix: detach + end session in `dispose()`, through
  `BridgeAttachment`, so a late callback of a superseded host cannot change the
  live session. Evidence: `test/regression/webview_lifecycle_test.dart`, passed
  in CI run 37835701145.
- [x] **BUG-012 (P1)** Rate limiter used `num.clamp` where an `int` is required
  (type error risk). Fix: explicit integer arithmetic.
- [x] **BUG-013 (P2)** `watchPosition` / `getCurrentPosition` had no timeout
  argument. Fix: `timeoutMs` (1..60000) mapped to the location time limit.

### Architecture

- [x] **ARCH-001 (P2)** Unused nested `pubspec.yaml` files in `lib/packages/*` and
  `lib/plugins/*` (not wired into the build). Fix: removed; single package.
- [x] **ARCH-002 (P1)** Capability metadata (`supportsStreaming`, `supportsCache`,
  `maxConcurrentCalls`, `supportsBatch`) and the separate `cacheable` flag
  disagreed and were not enforced. Fix: `PluginCapabilities` is the single
  source; the manager enforces streaming, cache and concurrency.
- [x] **ARCH-003 (P2)** Dead code: `ArgsValidator`/`ArgSchema`, `MemorySink`,
  `FileSink` (stub that never wrote), `PluginManifest`, `PermissionPolicy`,
  `checkPlugin`, `BatchRequest`, `PluginRequest.create`, `recordError`, unused
  cache patterns, lifecycle hooks `onPause`/`onResume`, unused `http`/`uuid`
  dependencies, unused `allowFileAccess`/`defaultTimeoutMs` configuration.
  Fix: removed or wired.
- [x] **ARCH-004 (P2)** The bridge depended on `webview_flutter`. Fix:
  `JsExecutor` abstraction; only `WebViewHost` touches the WebView.
- [x] **ARCH-005 (P3)** Duplicate `MainActivity` in `com/example/sweetmelon`
  (not referenced by the manifest). Fix: removed.
- [x] **ARCH-006 (P2)** Two validation result types (`ValidationResult`,
  `ArgsValidationResult`). Fix: one type with optional error code.
- [x] **ARCH-007 (P3)** Hard-coded 30 s timeout in the manager ignored the guard
  configuration. Fix: the guard's default is used.

### Statistics / Metrics

- [x] **STAT-001 (P1)** `errorCount` was never incremented and error paths
  (validation, permission, rate limit, timeout, exceptions) were not recorded.
  Fix: each call's outcome is recorded once in `totalCalls`; failures are also
  counted in `errorCount`; `activeCalls` returns to 0 when idle.

### Concurrency

- [x] **CONC-001 (P1)** `maxConcurrentCalls` not enforced. Fix: an in-flight
  counter per plugin in `PluginManager`; excess calls fail fast with
  `RATE_LIMIT_EXCEEDED` (retryable). Camera uses 1 because the image picker
  rejects concurrent presentations.
- [x] **CONC-002 (P2)** Execution guard counted duplicate request ids incorrectly.
  Fix: reference-counted in-flight map.

### Permissions

- [x] **PERM-001 (P1)** Permission denial now includes `status`
  (`denied` / `permanentlyDenied` / `unsupported`, the `PermissionState` values)
  in error details so the JS side can prompt for settings. The check runs on
  every call for each permission the plugin declares.

### Performance

- [x] **PERF-001 (P2)** LRU eviction was O(n) on each insert and overwrites
  evicted an unrelated entry. Fix: `LinkedHashMap` based O(1) LRU; overwrites do
  not evict.
- [x] **PERF-002 (P3)** Gradle heap of 8 GiB (`-Xmx8G`) would fail on hosted
  runners. Fix: reduced to 3 GiB (`-Xmx3G`; see 5b for the values tried).

### Tests

- [x] **TEST-001 (P0)** No tests existed. Fix: unit, integration, security,
  regression, performance-smoke and JavaScript-SDK tests (`test/`, `test/js/`).
- [x] **TEST-002 (P1)** No coverage measurement. Fix: `flutter test --coverage`
  with a line-coverage gate (`.github/scripts/coverage_gate.py`, 55 %).
- [x] **TEST-003 (P2)** No device-level E2E. Fix: `integration_test/app_test.dart`
  (the planned file name was changed; see 5b) run on an Android emulator in CI.
  It covers boot and the storage path through the engine, not JS inside the WebView.

### CI

- [x] **CI-001 (P0)** No CI. Fix: `.github/workflows/ci.yml` (format, analyze,
  unit/integration/security tests, JS SDK tests, coverage gate, Android debug
  build, Android emulator E2E).
- [x] **CI-002 (P2)** No `.gitignore`: `.dart_tool`, `build`, `local.properties`,
  keystores and IDE files were committable. Fix: Flutter-appropriate `.gitignore`.

### Documentation

- [x] **DOC-001 (P2)** README was empty. Fix: README with setup, commands and layout.
- [x] **DOC-002 (P2)** No architecture, security or testing documentation. Fix:
  `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/TESTING.md`.
- [x] **DOC-003 (P3)** Stale comments/strings (`Hello World` display name,
  placeholder RunnerTests). Fix: corrected.

### Known platform gap

- [x] **IOS-001 (P2)** The iOS project had no `ios/Podfile` and was never built.
  Resolved: `ios/Podfile` is committed with the `permission_handler` macros, the
  deployment target is 13.0, and an iOS job in CI builds the app on macOS with
  `flutter build ios --debug --no-codesign`. Running on a device is not covered.

## 5a. Known-finding mapping (SM-001 … SM-012)

The user-supplied findings are mapped to the plan IDs below. Each row names the
fix and the test that protects it.

| SM | Finding | Plan ID(s) | Fix | Protecting test |
| --- | --- | --- | --- | --- |
| SM-001 | JS trust boundary / unrestricted JS | SEC-001, SEC-004, ARCH-004 | navigation policy, top-frame SDK, per-session token, JsExecutor | `navigation_policy_test`, `message_bridge_test` (token), `bridge_sdk.test.mjs` |
| SM-002 | Capabilities not enforced | ARCH-002, CONC-001 | streaming / batch / cache / concurrency enforced in manager | `plugin_manager_test` (streaming, batch, maxConcurrentCalls) |
| SM-003 | Storage writes cacheable, no invalidation | BUG-001 | cacheable methods are read-only; writes invalidate | `plugin_manager_test` regression: write executes, write invalidates |
| SM-004 | Guard timeout hard-coded, no concurrency enforcement | ARCH-007, CONC-001, CONC-002 | timeout from `PluginManagerConfig`; per-plugin in-flight limit; duplicate-id rejection | `plugin_manager_test` (timeout from config, concurrency, duplicate) |
| SM-005 | `errorCount` never incremented; error paths unrecorded | STAT-001 | every failure path records stats and a trace | `plugin_manager_test` (errorCount on each failure path, traces) |
| SM-006 | Bridge lifecycle: stale state across reloads | BUG-003, BUG-011 | sessions; stale responses dropped; dispose ends session | `message_bridge_test` regression: stale-session response dropped |
| SM-007 | Pending request cleanup | BUG-003, CONC-002, BUG-011 | in-flight entries removed in `finally`; `cancelAll` on dispose; batch settles | `security_units_test` (guard), `plugin_manager_test` (dispose cancels) |
| SM-008 | Batch lifecycle (unsettled batches) | BUG-002, BUG-007 | per-item results always present; batch timeout; stopOnError semantics | `plugin_manager_test` batch group, `bridge_sdk.test.mjs` batch timeout |
| SM-009 | Geolocation watch discards positions | BUG-005 | `watchId` streams delivering `geolocation.position`; max 4; cleanup | `geolocation_lifecycle_test` (watch IDs, stream error removes watch, watch limit); the native position stream is not device-tested (TEST-003) |
| SM-010 | Error contract leaks internals | SEC-003 | generic message to JS; details logged natively | `plugin_manager_test` error-contract group |
| SM-011 | Geolocation stream lifecycle | BUG-005 (cleanup) | subscriptions removed on cancel, end, error and dispose | `geolocation_lifecycle_test` (`clearWatch` cancels, dispose cancels all); the platform subscription is not device-tested |
| SM-012 | Resource disposal | BUG-011, BUG-005, BUG-003 | `WebViewHost.dispose` detaches; bridge/manager/registry dispose | `message_bridge_test` (dispose), `plugin_manager_test` (dispose) |

SM-007 and SM-011 are covered at the Dart level only. The native side (the real
geolocation subscription and the picker) is not exercised on a device; see
`docs/TESTING.md`, "What is not covered".

## 5b. Deviations from the original plan

Each deviation is a decision made during implementation. The reason is recorded
in `docs/WORKLOG.md`.

- **SEC-003 message.** The plan text says `Internal error`. The bridge still sends
  `Internal error` for its own failures. The plugin manager sends
  `Plugin execution failed` for exceptions thrown by plugins, which says which
  step failed without naming internals. Both are generic.
- **SEC-005 TTL.** Set to 5 s as planned. The manager reports `status` in
  details; `restricted` and `notDetermined` from the plan are reported as
  `denied` because `permission_handler` does not expose them on every platform.
- **SEC-007.** The inspector is gated by `kDebugMode` (not by the
  `enableDebugging` config) so that release builds cannot show it even with a
  misconfigured host.
- **BUG-001 invalidation.** Cache keys are not generation-based. A successful
  non-cacheable call invalidates the plugin's cache by key prefix. This is
  simpler and has the same observable effect. The BUG-001 `Fix` line above says
  the same.
- **BUG-007.** Parallel batches run concurrently; `stopOnError` is applied only
  to sequential batches. Documented in `docs/SECURITY.md`.
- **BUG-012.** The limiter uses integer arithmetic on milliseconds; no `clamp`.
- **PERF-002.** Heap reduced from 8 GiB to 3 GiB (`org.gradle.jvmargs=-Xmx3G`). The
  plan suggested 4 GiB; 4 GiB and then 2 GiB were tried. 2 GiB failed in
  `JetifyTransform` with `Java heap space`. Jetifier is also disabled
  (`android.enableJetifier=false`): every plugin here is AndroidX, and the
  transform was the main memory consumer. Kotlin daemon heap is 1.5 GiB.
- **Toolchain minimums (CI-001).** Flutter's current minimums are Gradle 8.14,
  AGP 8.11.1 and Kotlin 2.2.20. The repo was on Gradle 8.10.2, AGP 8.7.0 and
  Kotlin 1.8.22 and failed the debug build. The versions were raised to the
  minimums.
- **Folders.** Tests live in `test/unit/`, `test/security/`, `test/regression/`,
  `test/integration/`, `test/performance/` and `test/js/`, as in 9.
- **Format and analyzer gate.** The plan asked for `dart format
  --set-exit-if-changed` and `flutter analyze --fatal-infos`. CI runs
  `flutter analyze --fatal-warnings`. The format check runs in CI through
  `.github/scripts/format_report.sh`, which also publishes the diff of any
  unformatted file as a check run.
- **Coverage gate.** Coverage is generated, uploaded, and enforced at 55 % by
  `.github/scripts/coverage_gate.py` in CI (TEST-002).
- **E2E.** `integration_test/app_test.dart` replaces the planned
  `app_e2e_test.dart` (TEST-003). It covers boot, the WebView host and the storage path
  through the engine. It does not drive JavaScript through the WebView (TEST-003).

## 6. Risks

| Risk | Mitigation |
| --- | --- |
| Dart code could not be compiled inside the sandbox | Every change is verified by CI; failures are fixed and re-pushed (section 14) |
| `permission_handler` on iOS needs Podfile macros | `ios_permissions.py` checks the Podfile in CI; the iOS job builds the app without codesign (IOS-001). The app is not run on an iOS device. |
| Parallel batch cannot cancel already dispatched calls | Documented limitation; sequential mode honours `stopOnError` |
| Dart futures cannot be cancelled after timeout | Guard reports `TIMEOUT`; underlying plugin work may finish later (documented) |
| WebView iframes can still call the raw channel | Token prevents use; documented in SECURITY.md |

## 7. Priorities

1. P0: SEC-001, SEC-002, BUG-001, TEST-001, CI-001.
2. P1: SEC-003/004/005/006, BUG-002/003/004/005/008/009/010/012, STAT-001,
   CONC-001, PERM-001, ARCH-002, TEST-002, TEST-003.
3. P2/P3: remaining items.

Technical dependency order: protocol and sandbox before plugins; capabilities
before concurrency and cache; tests alongside each change; CI last, then
verified by GitHub Actions.

## 8. Implementation Plan

- [x] 8.1 Baseline and plan/worklog files
- [x] 8.2 Remove dead code and unwired packages (ARCH-001, ARCH-003, ARCH-005)
- [x] 8.3 Protocol validation and error contract (BUG-006, SEC-003, SEC-004, ARCH-006)
- [x] 8.4 Bridge sessions, token, queue bound, batch semantics, events (SEC-001, BUG-002/003/004, ARCH-004)
- [x] 8.5 WebView host: navigation policy, SDK in top frame, lifecycle (SEC-001, BUG-011)
- [x] 8.6 Security components: sandbox path, permissions, rate limiter, guard, concurrency (SEC-002, SEC-005, SEC-008, CONC-001/002, BUG-012)
- [x] 8.7 Cache LRU and mutation invalidation (BUG-001, PERF-001)
- [x] 8.8 Plugin manager pipeline, capabilities and metrics (ARCH-002, STAT-001, SEC-003, BUG-007)
- [x] 8.9 Plugins: storage, camera, geolocation (SEC-002, SEC-009, BUG-005/008/009/013, CONC-001)
- [x] 8.10 Platform config: manifests, plist, Gradle signing and heap (SEC-006, BUG-010, PERF-002)
- [x] 8.11 Tests: unit, integration, security, regression, perf smoke, JS SDK, E2E
- [x] 8.12 CI workflow and coverage gate (CI-001, TEST-002, TEST-003)
- [x] 8.13 Documentation (DOC-001..003, CI-002)

## 9. Test Plan

See `docs/TESTING.md`. Summary:

- Unit: protocol, bridge, navigation policy, sandbox path, rate limiter, guard,
  permission manager, concurrency limiter, cache, registry, manager, plugins.
- Integration: JS-shaped JSON → bridge → manager → plugin → response
  (`test/integration`).
- Security: traversal, symlink escape, unauthorized token, malformed protocol,
  oversized message, unknown plugin/method, permission denial, rate abuse,
  concurrency abuse, error disclosure (`test/security`).
- Regression: tests for the BUG/SEC/CONC findings in `test/regression`, plus
  regression-named tests in `test/unit` (see `docs/TESTING.md`).
- JavaScript SDK: the injected SDK is executed in a Node VM (`test/js`).
- E2E: Android emulator, real WebView (`integration_test`).

## 10. Security Plan

Covered in `docs/SECURITY.md` (threat model, trust boundary, origin policy,
permissions, storage, rate limiting, concurrency, error disclosure, known
limitations).

## 11. Performance Plan

- Cache LRU is O(1) (PERF-001).
- Benchmark-style smoke tests in `test/performance` assert bounded time for
  bridge round trips, cache hit/miss and event throughput.
- Message size limit bounds worst-case JSON parse cost (SEC-004).

## 12. CI/CD Plan

`.github/workflows/ci.yml`, triggered on `push` to `main` and `arena/**`, on
`pull_request`, and manually:

1. `analyze-and-test` — `flutter analyze --fatal-warnings`; `format_report.sh`
   (dart format check); `flutter test test/ --coverage`; coverage gate (55 %).
2. `js-sdk-tests` — Node VM tests for the injected SDK.
3. `android-build` — debug and release APK builds.
4. `android-e2e` — emulator run of `integration_test`, through `run_e2e.sh`.
5. `ios-build` — macOS build without codesign (CocoaPods; SPM disabled).

Release signing is injected via environment variables only; no secret is stored
in the repository.

## 13. Documentation Plan

README, docs/ARCHITECTURE.md, docs/SECURITY.md, docs/TESTING.md, this plan and
the worklog. Each document is kept in line with the code in the same change.

## 14. Acceptance Criteria

- All P0/P1 findings are `[x]` with tests.
- `flutter analyze --fatal-warnings`, `flutter test`, Node SDK tests, Android
  debug and release builds, and the Android E2E pass in GitHub Actions on the
  pushed commit, including `dart format` and the 55 % coverage gate.
- Docs describe the behaviour in the code.

## 15. Completion Status

Work items are complete in code. Verification status is recorded in the worklog
and in the final verification section below.

Blocked items: none. IOS-001 was blocked by the lack of a Flutter SDK and a
macOS host in the sandbox. It is no longer blocked: the iOS job in CI builds the
app on a macOS runner (see section 12). The remaining gap is that the app is not
run on an iOS device or simulator, which is recorded in `docs/TESTING.md`.

## 16. Final Verification

Final verification pass 5 is recorded in `docs/WORKLOG.md`. This section is the summary.

**Final Status: COMPLETE**

### Repository state

- Branch `arena/a3bec261-sweet-melon`. Local HEAD equals `origin` HEAD at each
  push, and the working tree was clean after each push.
- Production code, tests, Android and iOS configuration and CI workflow are
  unchanged since `8b1fa1a`. That commit's CI run 37835701145 was green. Later
  commits `5fe5557` and `bdb204c` change only `docs/`.
- CI runs that are green on the exact commits: `37836821932` on `5fe5557`, and
  `37839069513` on `bdb204c`.

### CI (run 37839069513, commit `bdb204c`)

| Job | Result | Steps verified |
| --- | --- | --- |
| Injected JavaScript SDK (Node VM) | PASS | `node --test test/js/bridge_sdk.test.mjs` |
| Analyze, unit, security and regression tests | PASS | static analysis (`--fatal-warnings`), tests with coverage, coverage gate, format check, coverage upload |
| Android build (debug and release) | PASS | release is unsigned (no keystore in CI) |
| Android end-to-end (emulator) | PASS | `run_e2e.sh` (exit code 0; two `E2E_OK` markers required by the script) |
| iOS build (macOS, no codesign) | PASS | CocoaPods install and `flutter build ios --debug --no-codesign` |

Coverage: the gate passed at the enforced 55 % threshold. The exact measured
percentage for the final commit was not recoverable from the available CI
logs or artifacts in this pass (both downloads failed with EOF). The earlier
58.18 % belongs to `69b6d17` and is not the final value. The threshold was not lowered.

Local verification: only the JS SDK suite was run locally (Node 22.22.3, 16/16 pass).
Dart and Flutter are not installed in this sandbox, so Dart format, analyze and
tests are verified in CI only.

### Requirement evidence

| Item | Requirement | Implementation | Test | Verification |
| --- | --- | --- | --- | --- |
| BUG-007 | Sequential `stopOnError`: later requests are not dispatched; skipped requests get a result; parallel limitation documented | `PluginManager.executeBatch` (sequential loop checks `settled` and `stopOnError`; skipped requests get `CANCELLED`) | `test/regression/batch_stop_on_error_test.dart` | Real manager path; passed in CI |
| BUG-008 | Picker cancel: `ImagePicker` null → `PluginException(cancelled)` → `_fail` → `CANCELLED`, slot released, counted in `errorCount` | `CameraPlugin._takePhoto`; manager `on PluginException`; `ExecutionGuard` `finally` | `test/regression/camera_cancel_test.dart` (response code, repeated calls, stats) | Real engine path with a fake picker; passed in CI |
| BUG-011 | Dispose detaches the executor and ends the session; late callbacks cannot change the live session | `WebViewHost.dispose` → `BridgeAttachment.detach` → `MessageBridge.detachJsExecutor` and `endSession` | `test/regression/webview_lifecycle_test.dart` (real `MessageBridge`) | Passed in CI. The widget callbacks themselves are not driven by a test (see TESTING.md) |
| 8.5 | Navigation policy, SDK in top frame, lifecycle | `NavigationPolicy` (wired in `WebViewHost`); SDK `window.top` guard; `BridgeAttachment` | `navigation_policy_test`, `bridge_sdk.test.mjs` (iframe refusal), `webview_lifecycle_test` | Passed in CI and locally (JS) |
| 8.9 | Storage, camera, geolocation behaviour | `SandboxPath`, storage size limits; camera cancel and validation; geolocation watches and timeout | `storage_path_test`, `storage_security_test`, `camera_validation_test`, `camera_cancel_test`, `camera_concurrency_test` (CONC-001), `geolocation_lifecycle_test`, `argument_validation_test` | Passed in CI |
| 8.10 | Manifests, Info.plist, Gradle signing and heap | `AndroidManifest.xml` (CAMERA, FINE and COARSE location); iOS usage strings; `build.gradle.kts` signing from env; `gradle.properties` heap | Android and iOS CI build jobs | Passed in CI |
| 8.11 | Unit, integration, security, regression, performance smoke, JS SDK, E2E | `test/unit`, `test/integration`, `test/security`, `test/regression`, `test/performance`, `test/js`, `integration_test` | the Dart suite and JS suite, E2E job | Passed in CI |

### Plan status

- Every item is `[x]`. None is `[~]`, `[ ]`, `[!]` or `[-]`.
- The `[-]` status is not used anywhere in this plan. Its meaning is written in the legend.
- SM-001 to SM-012 are mapped in section 5a. Two of them (SM-007, SM-011) are
  covered at the Dart level only, as stated there.
- No P0 or P1 item is open.

### Historical E2E incident

Run 37815334536 (commit `1b00c87`) failed in the Android E2E job. The check-run
annotations report `e2e.rc was not written`. The full logs could not be read.
The root cause is not conclusively established, and this document does not call
the failure a flake. The E2E harness was then rewritten (`cb938ff`): it writes
`e2e.txt` first, and an EXIT trap writes `e2e.rc` on every path. Subsequent
E2E runs passed: `37834548307`, `37835701145`, `37836821932` and `37839069513`.

### Known limits (documented, not blockers)

- No automated test runs the page's JavaScript inside the real WebView. The Node
  VM tests cover the SDK code, and the device test covers boot and the storage path.
- The iOS job builds the app without codesign. The app is not run on an iOS device or simulator.
- The native geolocation subscription and the image picker are not exercised on a
  device. Their Dart-level logic is tested with fakes.
- Parallel batches do not apply `stopOnError` (documented in `docs/SECURITY.md`).
- The symlink tests are skipped on Windows only (`skip: Platform.isWindows`). CI runs on Linux.
- The Android and iOS bundle identifiers are placeholders (`com.example.sweet_melon`).
  `README.md` says to change them before publishing.
