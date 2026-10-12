# Worklog

Permanent journal of the Sweet-Melon audit, hardening, test and CI work.
Every significant iteration records: timestamp, phase, finding, decision, files
changed, tests executed and result.

---

## 2026-10-08

### Phase
Repository Audit (baseline)

### Environment / Baseline
- Branch: `arena/a3bec261-sweet-melon` (from `main` @ `feca87b`).
- Git status before changes: clean working tree.
- Remotes: `origin` = https://github.com/legionir/Sweet-Melon.git.
- Repository type: Flutter application (single root package `sweetmelon`) with
  in-tree "packages" under `lib/packages/*` and `lib/plugins/*`.
- Tracked files: 108. No `.gitignore`, no `test/` directory, no `.github/`
  directory, no CI workflow, no `pubspec.lock`.
- Build status: **not runnable in the audit sandbox** — no Flutter/Dart SDK is
  installed and `pub.dev` / `storage.googleapis.com` are not reachable from the
  sandbox (allowed hosts: github.com, registry.npmjs.org, pypi.org). Verification
  therefore runs on GitHub Actions (see `.github/workflows/ci.yml`).
- Test status: **0 tests** existed.
- Lint / static analysis status: never executed in the repository (no CI).
- Dependency status: `http` declared but unused; `uuid` only used by dead
  factories; `image_picker`, `geolocator`, `webview_flutter` in use.
- Existing CI status: none.
- TODO/FIXME/HACK/XXX: only two `TODO` comments, both in
  `android/app/build.gradle.kts` (application id and release signing).

### Findings (summary; full list in `docs/AUDIT_EXECUTION_PLAN.md`)
- Trust boundary: `flutterBridge` JavaScript channel is exposed to every frame;
  no session token; navigation is unrestricted when `allowedHosts` is empty.
- Storage: `listFiles` skips `..` validation and symlinks are not contained.
- Cache: write operations (`set`, `remove`, `writeFile`, …) are cacheable and
  never invalidate the cache.
- Bridge: batch failures never resolve the JS promise; `_isReady` survives page
  reloads; unbounded pending-script queue.
- Stats: `errorCount` is never incremented.
- Capabilities `supportsStreaming`, `supportsCache`, `maxConcurrentCalls` are
  metadata only.
- Permissions: camera/storage/location always granted by `StaticPermissionProvider`.
- Geolocation `watchPosition` discards every position update.
- Android: release signed with debug key; duplicate unused `MainActivity`;
  manifest lacks CAMERA/LOCATION permissions; iOS lacks usage descriptions.
- No `.gitignore`, no tests, no CI, empty README.

### Decision
Work item order follows the plan: P0 security/data-integrity first, then P1
bridge/plugin correctness, then tests, CI, documentation. Dart code is verified
through CI; every Dart change is covered by tests in `test/`.

### Files
- docs/AUDIT_EXECUTION_PLAN.md (created)
- docs/WORKLOG.md (created)

### Tests
- None executed yet (baseline).

### Result
BASELINE RECORDED

---

## 2026-10-08 — Implementation pass 1 (engine, security, plugins, tests, CI, docs)

### Verification environment
- The Flutter and Dart SDKs are not installed here and cannot be downloaded
  (only GitHub, npm, PyPI are reachable). Dart code is therefore **not compiled
  locally**. Compilation, analysis and tests run in GitHub Actions. Node is
  available locally and was used for the JS SDK test design.

### Decisions (recorded instead of asking)
- Removed `FileSink`/`MemorySink`: the file sink never wrote anything; a
  documented console sink is the only sink. (ARCH-003)
- Removed the event emitter from `PluginRegistry`'s public API in favour of an
  emitter passed at construction; plugins emit through `Plugin.emit`. (BUG-005)
- Renamed the navigation verdict type to `NavigationVerdict`: `webview_flutter`
  exports a `NavigationDecision` enum and the names would clash.
- `ValidationResult` is the single validation type; the error code is set by
  the manager from `PluginErrorCode` (ARCH-006).
- Permission TTL 5 s (plan). Heap 4 GiB (plan).
- Release signing: `SWEETMELON_KEYSTORE_*` environment variables; no keystore
  means an unsigned release. R8 minification was considered and not enabled,
  to avoid release-only breakage without a device to verify on.
- `RECORD_AUDIO` was considered for Android and not added: the picker is an
  intent and does not need it. iOS keeps the microphone usage string because
  video capture on iOS needs it.

### Identity check: MainActivity (ARCH-002 / ARCH-005)
- `android/app/build.gradle.kts` sets `namespace = "com.example.sweet_melon"`,
  and the manifest uses `.MainActivity`.
- The file deleted under `com/example/sweetmelon/` declared
  `package com.example.sweetmelon`, which does not match the namespace. It was
  the wrong one.
- The file kept, `com/example/sweet_melon/MainActivity.kt`, matches the manifest.
- Deletion confirmed correct.

### Changes
- `pubspec.yaml`: removed `http`, `uuid`; added `permission_handler`,
  `integration_test` (dev). Nested per-package pubspecs removed (ARCH-001).
- Protocol: strict validation, identifiers without backslash (regex bug fixed:
  `\\-` inside the class had let a backslash through — regression test added).
- Bridge: sessions, token, size limit, bounded queue, stale-response drop,
  batch envelope handling, double-encoded events. (SEC-004, BUG-002/003/004)
- WebView host: navigation policy, top-frame SDK, session start/end on page
  start/finish, detach on dispose. (SEC-001, BUG-011)
- Engine: pipeline with capability enforcement, concurrency limit, permission
  status in details, cache read-only + invalidation, error contract, stats and
  traces on every failure path, batch timeout that settles every item.
  (SEC-003, SM-002..005, SM-010, CONC-001, PERM-001, STAT-001, BUG-001/002/007)
- Security: sliding-window rate limiter with bounded keys (BUG-012, SEC-008);
  execution guard with timeouts, duplicate ids, cancel-all (CONC-002);
  permission manager with OS provider and TTL (SEC-005).
- Cache: O(1) LRU, JSON copies, no eviction on overwrite (PERF-001).
- Storage: sandbox path validation, symlink containment, size limits, cache
  only for read methods (SEC-002, SEC-009, BUG-001).
- Camera: `CANCELLED` on user cancel, single concurrent call, validation
  (BUG-006/008, CONC-001). Camera validation is not unit-tested yet.
- Geolocation: watch streams with `watchId`, events, max 4 watches, cleanup,
  `timeoutMs` (BUG-005, BUG-013, SM-009, SM-011).
- Devtools: bounded queue (PERF-002), payload redaction (SEC-007), no
  `removeAt(0)`, precomputed search text, debug-only UI (SEC-007).
- DI: rewired for the new constructors; `ServiceLocator.dispose` order fixed.
- Android: CAMERA, location permissions; release signing from env (SEC-006,
  BUG-010); heap 4 GiB (PERF-002).
- iOS: usage strings; removed the leftover "Hello World" display name (BUG-010,
  DOC-003).

### Tests written (not yet executed)
- `test/unit/protocol_test.dart`, `navigation_policy_test.dart`,
  `storage_path_test.dart`, `security_units_test.dart`,
  `message_bridge_test.dart`, `plugin_manager_test.dart`
- `test/security/storage_security_test.dart`
- `test/js/bridge_sdk.test.mjs` (Node VM over the shipped Dart template).
  **Executed locally with Node 22: 16/16 pass.** (Re-run in pass 5 on Node
  22.22.3: 16/16 pass.) One test initially encoded the
  payload twice; it was corrected to match `MessageBridge.emitEvent` (the SDK
  receives JSON text). The SDK itself was not changed for that.
- `integration_test/app_test.dart` (emulator)
- Helpers: `test/helpers/fakes.dart`

### CI
- `.github/workflows/ci.yml`: analyze + unit/security tests with coverage, Node
  SDK tests, Android debug + release builds, Android emulator run of the
  integration test.

### Docs
- README, docs/ARCHITECTURE.md, docs/SECURITY.md, docs/TESTING.md written.
- Plan updated: statuses `[~]` for implemented work awaiting CI; SM-001..012
  mapping and deviations added (sections 5a and 5b).

### Status
- Implementation: written. Verification: **pending CI**. No item may be marked
  `[x]` until the pushed commit's workflow runs green.

### CI verification log (GitHub Actions, branch arena/a3bec261-sweet-melon)

The Flutter SDK is not available in the sandbox, so every Dart and Android
result below comes from CI. Job logs cannot be downloaded from the sandbox
(the log storage host is unreachable), so diagnostics were moved into
check-run annotations by `.github/scripts/annotate_output.py`.

Failures found and fixed, in order:
1. `ci.yml` did not parse: an unquoted step name contained `:`. Quoted.
2. Analyzer: missing `dart:async` (Completer), missing `CacheManager` import in
   `test/helpers/fakes.dart`, missing `package:flutter/foundation.dart` for
   `kDebugMode` in `home_screen.dart`. Fixed.
3. Steps were using `cmd; rc=$?`. GitHub runs `bash -e`, so the script stopped
   before the diagnostic step. Changed to `cmd || rc=$?`.
4. Android: Flutter's current minimums are Gradle 8.14, AGP 8.11.1 and Kotlin
   2.2.20. The repo pinned Gradle 8.10.2, AGP 8.7.0 and Kotlin 1.8.22. Bumped to
   the minimums; this is a toolchain requirement, not a preference.
5. E2E step: the first failure was the same Gradle error, but the step still
   reported success. Added explicit checks for failure text and for
   `All tests passed`.

Result at this point (commit history on the branch):
- JavaScript SDK tests: pass (16/16 locally with Node 22, and in CI).
- analyze (`--fatal-warnings`) and unit/security/regression tests: pass in CI.
- Android debug and release build: pass in CI.
- Android emulator integration test: see the latest run; the step is gated on
  an explicit `All tests passed` line.

### Final CI status for this session (latest run on the branch)

| Job | Result | Evidence |
| --- | --- | --- |
| Injected JavaScript SDK (Node VM) | PASS | 16/16 tests |
| Analyze, unit, security and regression tests | PASS | `flutter analyze --fatal-warnings`; `flutter test test/` |
| Android build (debug and release) | PASS | debug APK and unsigned release APK built |
| Android end-to-end (emulator) | FAIL | app boots; first test passes; `flutter test` stops before the summary |

Overall: **NOT COMPLETE**. Open items:
- E2E on the emulator (TEST-003, CI-001, 8.11, 8.12). Diagnosis so far is in
  the plan's section 16. Not reproduced locally.
- Coverage gate script (TEST-002).
- Formatter check (`dart format`) is not in CI.
- BUG-005 (geolocation event path), BUG-009 (camera validation), BUG-011
  (dispose path), SEC-007 (inspector redaction): implemented, no automated test.
- BUG-010 iOS: usage strings present, iOS not built (IOS-001 blocked: no
  Podfile, no macOS host).
- Plan statuses: 44 `[x]`, 17 `[~]`, 1 `[ ]` (the legend line).

Rejected or corrected during this pass:
- A manual emulator start (own step) was tried: the system image download was
  too slow in the sandbox runner (the sdkmanager timeout hit at ~60%). Reverted to
  android-emulator-runner.
- Gradle wrapper, AGP, and Kotlin were raised to Flutter's minimums (Gradle 8.14,
  AGP 8.11.1, Kotlin 2.2.20). Not a preference; the build fails otherwise.
- A test that double-encoded the SDK payload was corrected to match the native
  side. The SDK was not changed for that.

---

## 2026-10-08 — Completion pass 2

### Baseline (start of pass 2)
- Branch `arena/a3bec261-sweet-melon`, head `6838f65` at start; working tree clean.
- CI on head: analyze/unit PASS, JS PASS, Android build PASS, E2E FAIL, iOS not run (macOS runner not acquired).

### E2E: root cause (finding E2E-001)
Recorded from the run logs available at the time. Not re-verified in pass 5,
because those logs are no longer retrievable.
- Earlier E2E failures were reported by the pass-check grep in
  `.github/scripts/run_e2e.sh`, not by the test process itself. Runs
  37803775317 and 37805464783 had `e2e.rc = 0` but failed the grep.
- Theories that a process was killed or ran out of memory are withdrawn. They
  were not supported by the evidence.
- Fix: the integration test prints an `E2E_OK:` marker per passing test. The
  script requires exit code 0, no failure text, and exactly two markers.
- Verification: CI run 37809546838, job "Android end-to-end (emulator)": PASS.

### Other changes in this pass
- Format: `dart format` was failing on 24 files. A CI step now publishes each
  file's formatter diff as a check run; the diffs were applied with `git apply`
  (storage_plugin.dart by hunk, since a NUL escape in a context line did not
  match). Verification: pending the next CI run.
- Coverage gate: `.github/scripts/coverage_gate.py` runs after unit tests.
  Threshold is taken from repo variable `COVERAGE_MIN`; unset means 0 for this
  measurement run. The real threshold will be set from the measured value.
- iOS: a macOS job generates the missing `ios/Podfile` from the Flutter template
  (`flutter create`), adds the permission_handler macros, and builds without
  codesigning. Previously IOS-001 was blocked for "no Podfile / no macOS". Neither
  is a blocker: the Podfile is generated in CI and macOS runners exist on GitHub.
  The first macOS attempt was not picked up by a runner (capacity); it is retried.
- Tests added: `test/unit/devtools_redaction_test.dart` (SEC-007),
  `test/unit/camera_validation_test.dart` (BUG-009),
  `test/unit/geolocation_lifecycle_test.dart` (BUG-005, BUG-013, SM-009, SM-011).
- Inspector trace line cleaned up (plain quotes inside the interpolation).

### Open after this push
- Format and coverage results from CI (not yet verified).
- iOS job result (not yet verified).
- BUG-011 (WebViewHost dispose): no automated test yet.

### Result (pass 2)
- CI run 37822424205 on `69b6d17`: all five jobs PASS (JS SDK, analyze/unit/
  security/regression + coverage gate 55% + format, Android build, Android E2E,
  iOS build).
- Fixes made during the pass, each verified by a later run:
  - Format: 1 file (camera test) reformatted from the per-file CI diff.
  - Unit tests: the geolocation test source is a broadcast stream (several watches
    listen to it); the bounded-watch test awaits the async rejection.
  - iOS: `ios/Podfile` committed from the standard Flutter template (the repo had
    none). CI keeps CocoaPods integration (`flutter config
    --no-enable-swift-package-manager`), regenerates `Generated.xcconfig` for the
    runner (`flutter build ios --config-only`), then runs `pod install`.
  - E2E: one run failed inside the emulator-runner action before the test script
    ran (`e2e.rc not written`, job ~1 min). A rerun on the next commit passed. Cause
    not identified. Correction (pass 5): the earlier wording "treated as a flake"
    is withdrawn. The cause is not established; see the pass 4 entry.
  - Coverage: measured 58.18% on `69b6d17` only; gate default set to 55%.
- Plan items moved to `[x]` with green evidence: SEC-007 (redaction tested; inspector
  gated by kDebugMode), BUG-005, BUG-009 (camera validation), BUG-010 (manifests and
  Info.plist; builds green), IOS-001, TEST-002, TEST-003, CI-001, 8.12.
- Not done in this pass: BUG-007, BUG-008, BUG-011 tests; 8.5, 8.9, 8.11 completion;
  docs check against code; final audit. Section 16 lists them.

### 2026-10-08 — Completion pass 3: working-tree reconciliation
- Finding: the local checkout was at `feca87b` (main base) with ~48 uncommitted
  changes that did not match the CI-verified branch head `953d68c`.
- Decision: origin `arena/a3bec261-sweet-melon` at `953d68c` is the source of
  truth (it has the green CI run 37823734258). The local differences were saved to
  `/tmp/wt-backup/` (outside the repo) and the branch was reset to origin.
- Verification: `git status` clean at `953d68c`; 127 tracked files.

### 2026-10-08 — Completion pass 4: CI check, E2E investigation, BUG-007/008/011, docs audit
- **CI on `cb938ff`** (run 37833505393): JS SDK passed; analyzer failed on three
  `prefer_const` infos in `test/regression/argument_validation_test.dart`. Fixed in
  `ddacbd0` (`const Stream<Position>.empty()`). The run on `ddacbd0` (37833966486)
  is the one to check; its result is recorded in the final entry below.
- **E2E failure on run 37815334536 (commit `1b00c87`) is NOT proven to be a flake.**
  Earlier entries called it one; that classification is withdrawn. Evidence:
  - `gh run view --log-failed` and the job-logs API both fail with an EOF from the
    Actions results service, so the full log could not be read.
  - The job's check-run annotations show `e2e.rc was not written` and
    `The process '/usr/bin/sh' failed with exit code 1`. The annotation for
    `e2e.txt` is absent, so the test output was never reported.
  - Interpretation: the script ended without the exit-code file being written.
    The most likely cause is that the detached test process did not write its
    exit code before the step ended. This is a hypothesis, not a proven root cause.
  - Response: `run_e2e.sh` was rewritten (`cb938ff`). It creates `e2e.txt` first,
    runs the test under `setsid`, writes `e2e.rc` from an EXIT trap on every path,
    and still requires exit code 0, no failure markers, and exactly two `E2E_OK`
    markers. The exit-code mechanism was not weakened. The E2E job timeout is 40
    minutes. The E2E status is unresolved until the E2E job of the final commit is
    green.
- **BUG-007 (batch stopOnError).** Fix as written in the plan: every request gets a
  result; sequential stop sends `CANCELLED` to skipped items; parallel dispatch is a
  documented limitation (`docs/SECURITY.md`). Evidence:
  `test/regression/batch_stop_on_error_test.dart`, plus the timed-out batch test
  (`BUG-007`/`BUG-002`). Resolved by tests, not by changing behaviour.
- **BUG-008 (camera cancel).** Decision: a user cancel is counted in `errorCount`,
  with code `CANCELLED`, not `EXECUTION_ERROR`. Rationale: the call produced no
  result, so it is a failed call (SM-005 requires every failure path to record
  stats). Excluding it would make `errorCount` under-report failed calls. Its code
  keeps it distinct from real execution errors. Evidence:
  `test/regression/camera_cancel_test.dart` (code and stats assertions).
- **CONC-001 for the camera (new test).** `test/regression/camera_concurrency_test.dart`
  holds the first `takePhoto` open with a `BlockingPicker`. A second call returns
  `RATE_LIMIT_EXCEEDED` without opening the picker. After release, the slot is free.
  This closes the gap in 8.9, where CONC-001 was listed but the camera's one-call
  limit had no test.
- **BUG-011 (WebView dispose).** `WebViewHost.dispose` detaches through
  `BridgeAttachment`. `test/regression/webview_lifecycle_test.dart` covers detach
  ending the session, no script after detach, late callbacks of a superseded host,
  and repeated detach. The widget's own callbacks are not driven by a test; see
  `docs/TESTING.md`.
- **iOS deployment target 12.0 → 13.0** (`project.pbxproj`, 3 places;
  `ios/Flutter/AppFrameworkInfo.plist`). Rationale: the Podfile already declares
  13.0, and the pods are built against it. The project never supported iOS 12
  consistently. The iOS CI job is the check for this change.
- **Coverage gate.** The regex in `ci.yml` was checked byte by byte (single
  backslashes). The threshold is unchanged at 55 %. Not lowered.
- **Docs audit against code.** Corrected:
  - `docs/TESTING.md` rewritten: it said device tests fail in CI, no coverage gate,
    no format check, and iOS not covered. Each row now names a real file. The iOS
    steps match `ci.yml`.
  - `docs/SECURITY.md`: `camera.takePhoto` is the only camera method limited to
    3/s (it said "Camera 3/s"). iOS is built without codesign in CI (it said it was
    not built). Rate-limit scope is now stated per method.
  - `docs/ARCHITECTURE.md`: states the bridge's purpose as JS → native plugin API,
    not a generic WebView wrapper. Pipeline order checked against code. Added
    `BridgeAttachment`. Corrected the http wording (only with `allowInsecureHttp`).
    Confirmed the `ServiceLocator` composition, the rate-limit rules, and the
    registry → bridge emitter cycle.
  - `plugin_manager.dart` header comment: the check order was stale. Fixed to match
    the code. This is a comment-only change.
  - `README.md`: framing as JS-to-native API bridge; minimum iOS 13.0.
- **Plan corrections.** SM-009 and SM-011 protecting tests now name the geolocation
  lifecycle tests. The native subscription is still not device-tested. Sections
  5b, 6, 12, 14 and 15 were stale (format, coverage gate, iOS "deferred", "IOS-001
  blocked", folders). They are updated.
- **Local verification.** Dart and Flutter are not installed in this sandbox. Format,
  analyze and tests can be checked only through CI. Nothing in this entry is a local
  PASS.

### Result (pass 4) — CI evidence and final statuses
- `ddacbd0` (analyzer fix): its run 37833966486 was cancelled when the next push
  superseded it. Its result is not counted. The fix is included in later runs.
- `505f8e2` (docs audit, CONC-001 test, BUG-008 stats): run 37834548307. JS SDK, Android
  build, Android E2E and iOS build passed. Analyze, unit and coverage passed. The
  format check failed on three files: `test/helpers/picker_fakes.dart` (an extra
  blank line), `test/regression/camera_cancel_test.dart` and
  `test/regression/webview_lifecycle_test.dart` (two test calls wrapped where the
  formatter joins them). I introduced the first two in this pass. The third was
  already in `08fe02d`. The formatter diffs from the CI check runs were applied
  exactly.
- `8b1fa1a` (format fix): run 37835701145. All five jobs passed: JS SDK; analyze,
  unit, security, regression, coverage gate and format; Android build (debug and
  release); Android E2E; iOS build (no codesign). The E2E job's exit-code file is 0.
- Coverage: the gate passed. The exact figure could not be read (log and artifact
  downloads failed with EOF). Not recorded as a number.
- E2E: passed on two consecutive runs with the rewritten `run_e2e.sh`
  (37834548307, 37835701145). The failure on 37815334536 is still unexplained. The
  evidence and the reason for not calling it a flake are in the entry above.
- Plan: BUG-007, BUG-008, BUG-011, 8.5, 8.9, 8.10 and 8.11 are `[x]`. Each is backed
  by a test or a CI job that passed on `8b1fa1a`. Section 16 is rewritten.
- Final commit: this docs-only commit. Its own CI run is the check for the branch head.

### 2026-10-08 — Final verification pass 5 (completion gate)
Scope: verify the existing final state. No audit rerun, no new features. The only
code-level check was the high-risk path review below; no production defect was found.

**Final Status:** COMPLETE (see `docs/AUDIT_EXECUTION_PLAN.md` section 16).

- **Final Commit:** the commit that adds this entry. It is docs-only and sits on
  `bdb204c`. Its own CI run is reported with the final response.
- **Branch:** `arena/a3bec261-sweet-melon`.
- **CI Run / CI Commit (verified code and docs state):** run `37839069513` on
  `bdb204c`, conclusion success. Production code is unchanged since `8b1fa1a`
  (CI `37835701145`, success).
- **Format:** PASS in CI (format check step, run 37839069513).
- **Analyze:** PASS in CI (`flutter analyze --fatal-warnings`). Not run locally.
- **Unit:** PASS in CI (`flutter test test/`). Not run locally.
- **Security:** PASS in CI. Security tests are part of `test/`. Not run locally.
- **Regression:** PASS in CI. Includes BUG-007, BUG-008, BUG-011, CONC-001 and BUG-009.
- **Coverage Gate:** PASS in CI at the enforced threshold.
- **Coverage Threshold:** 55 %. Not lowered.
- **Exact Coverage Percentage:** Not available from CI logs/artifacts. Both the
  job-log and artifact downloads failed with EOF in this pass. The 58.18 % figure
  belongs to `69b6d17` and is not the final value.
- **Android Build:** PASS in CI (debug and release; release unsigned, no keystore).
- **Android E2E:** PASS in CI (exit code file 0; the script also requires two `E2E_OK` markers).
- **iOS Build:** PASS in CI (no codesign).
- **JS SDK:** PASS in CI, and 16/16 pass when re-run locally on Node 22.22.3.
- **Documentation Audit:** done. Fixed: plan Status fragments; plan statements that
  contradicted the code (PERM-001 status values, STAT-001 `successCount`, PERF-002
  heap, SEC-007 gate, BUG-001 invalidation, CONC-001 class name, TEST-002/003 names);
  TESTING camera concurrency row; README regression wording; ARCHITECTURE line
  wrap. Confirmed: the bridge is described as JS → native plugin API, not a generic
  WebView wrapper; CI describes iOS build, coverage gate and format as present;
  camera rate limit is `camera.takePhoto` only; iOS deployment target 13.0 matches
  Podfile and `project.pbxproj`.
- **Final Audit:** done for the high-risk areas listed below. Checked by reading
  code and tests; the tests that exercise them passed in CI.
  - Bridge: size check before parse, then token check, then dispatch, with a
    catch-all that never raises.
  - Plugin manager: check order in code matches the documented order.
  - Permissions: checked on every call for each declared permission.
  - Navigation: `NavigationPolicy` is wired in `WebViewHost`.
  - Camera: cancel → `CANCELLED`; concurrency limit is one call.
  - Geolocation: watch cap of 4; `clearWatch` and dispose cancel subscriptions.
  - Storage: `normalizeSandboxPath` and `resolveWithinRoot`.
  - WebView lifecycle: `dispose` → detach → session ended.
  - Rate limiting and timeouts: per-method rules in `ServiceLocator`; timeout from
    configuration; batch timeout settles every item.
  - Cancellation, dispose and error mapping: `ExecutionGuard.finally` releases the
    slot; `PluginException` passes its code; other exceptions become `EXECUTION_ERROR`.
  - Statistics: failures counted in `errorCount` and `totalCalls`.
  - Android and iOS configuration: manifest permissions, env-based signing, Podfile
    macros, deployment target, bundle identifiers (placeholders, documented).
  - Marker search (TODO, FIXME, HACK, XXX, NotImplemented, SKIPPED, PENDING, BLOCKED)
    in `lib`, `test`, `integration_test`, `android`, `ios` and `.github`: no
    unresolved markers. The only `skip:` is the Windows platform gate on symlink tests.
- **Remote HEAD Verification:** before this entry, local HEAD and
  `refs/heads/arena/a3bec261-sweet-melon` on origin were both `bdb204c`. After the
  final push, the same check is repeated and reported with the final response.
- **Remaining Issues:** none that block completion. Known limits are listed in
  section 16 of the plan.

**Observed / inferred / unknown, for the historical incidents**
- Observed (run logs of the time): run 37815334536 reported `e2e.rc was not written`
  and exit code 1. The E2E-001 runs (37803775317, 37805464783) had `e2e.rc = 0` and
  failed the old grep. Both were recorded from logs at the time, and the logs cannot
  be re-read now.
- Unknown: the root cause of run 37815334536. The logs are unavailable.
- Inferred, not proven: the detached test process did not write its exit code before the step ended.
- Not claimed: that the failure was a flake. Subsequent runs passed (37834548307,
  37835701145, 37836821932, 37839069513), with the hardened harness (`cb938ff`).

**Corrections made in this pass**
- Pass 2's "treated as a flake" is withdrawn. The cause is not established.
- The 58.18 % coverage figure is labelled as the `69b6d17` value.
- Pass 1's "executed locally" JS SDK result was re-run on Node 22.22.3 and passes.
