# Security

## Threat model

The web page is **untrusted**. It may be an attacker's page, a page that was
compromised, or a third-party frame. The attacker can:

- run any JavaScript in the page and in any frame it can create;
- send arbitrary messages on the bridge, with any content and size;
- try to navigate the WebView to other origins or to local resources;
- call plugins with malformed, oversized or hostile arguments, at high rates.

The app, its native plugins and the OS are trusted. The attacker is not assumed
to have a copy of the app, its keystore or device access.

## Trust boundary and controls

| Area | Control | Finding |
| --- | --- | --- |
| Navigation | `NavigationPolicy`: default deny for remote hosts; `about:blank` only for `about:`; `javascript:`, `file:`, `intent:`, `content:`, `data:` always blocked; plain `http` only in debugging; sub-frames checked too. | SEC-001 |
| Frames | SDK is installed only in the top-level document (`window.top === window.self`). | SEC-001 |
| Session token | Random token per page session, issued by `startSession` and embedded in the SDK. Every message must carry it (constant-time comparison). The token is invalidated when navigation starts. Requests and `bridge_ready` with a wrong or old token are ignored. | SEC-001, SEC-004 |
| Stale responses | A response produced for a session that has ended is dropped; it is never sent into the next page. | BUG-003, SM-006 |
| Message size | Messages above 2 MiB are rejected before JSON parsing. | SEC-004 |
| Protocol | Strict validation of request, batch and option fields (`ProtocolException`). Identifiers are limited to `[A-Za-z0-9_-]` (1–128 chars); names to identifiers. | SEC-004, BUG-006 |
| Errors | JS receives only protocol codes and a short message. Raw exception text and stack traces are logged natively and never sent. Plugins use `PluginException` for messages that are safe to show. | SEC-003, SM-010 |
| Permissions | Checked before every call on the OS (`permission_handler`), with a 5 s cache so revocations are seen quickly. A denial returns `status` (`denied`, `permanentlyDenied`, `unsupported`) so JS can ask again or open settings. Unknown permissions are denied. | SEC-005, PERM-001 |
| Storage paths | `normalizeSandboxPath`: relative only, no `..` or `.`, no backslash, no NUL, no `:`, identifier-like segments, bounded length and depth. `resolveWithinRoot` resolves the nearest existing ancestor with `resolveSymbolicLinks` and rejects anything outside the sandbox root. Covered by a symlink test. | SEC-002 |
| Storage sizes | 5 MiB per file (read and write, measured on decoded bytes); 64 KiB per stored value; 128-char keys. | SEC-009 |
| Rate limiting | Sliding window per `plugin.method`, applied only after the plugin resolves. At most 1024 tracked keys, idle keys pruned. `camera.takePhoto` 3/s, `geolocation.getCurrentPosition` 5/s, all other methods 50/s. | SEC-008 |
| Concurrency | `maxConcurrentCalls` per plugin is enforced; camera is 1. Duplicate in-flight request ids are rejected. | CONC-001, CONC-002 |
| Timeouts | Every execution has a timeout from configuration (30 s default). Batches have an overall timeout. | SM-004, BUG-002, BUG-013 |
| Debug tooling | The inspector UI is only shown when `kDebugMode` is true, and it redacts `args` and `data` before storing them. | SEC-007 |
| Release signing | Release builds use a keystore from environment variables. Without one the release APK is unsigned; the debug key is never used. | SEC-006 |
| Android manifest | Only the permissions the plugins need: `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`. | BUG-010 |
| iOS | Usage strings are present for camera, microphone, photo library and location. | BUG-010 |

## Storage and cache integrity

Cached results are only returned for methods listed in `cacheableMethods`
(read-only). Writes always run. A successful write invalidates the plugin's
cache entries, so a read that follows a write is never stale (BUG-001, SM-003).

## Known limitations (accepted)

- **SEC-010 — camera paths.** Picker results are absolute paths in the
  application's temporary directory. JavaScript needs them to show or upload the
  files. The app does not give JavaScript access to arbitrary paths: the camera
  plugin only returns paths the picker produced.
- **Parallel batches and `stopOnError`.** Calls in a parallel batch start
  together, so `stopOnError` only applies to sequential batches (BUG-007). This
  is documented in the API, and sequential mode marks skipped items as
  `CANCELLED` with `Not executed`.
- **Origin of the page.** The bridge trusts any top-level document loaded from
  an allow-listed host. Hosts are configured in code (`WebViewHostConfig`); the
  default is an empty allow-list, so the app only shows its own HTML.
- **Token scope.** The token protects against other frames and stale pages. It
  does not authenticate a compromised allow-listed host.
- **Rate limits are per process.** They reset when the app restarts.
- **iOS.** Permission checks and usage strings are in place. The iOS project
  is built without code signing in CI (IOS-001), but the app is not run on a
  simulator or device, so iOS runtime permission behaviour is not tested.

## Reporting

Report security issues to the repository owner privately. Do not open a public
issue with exploit details.
