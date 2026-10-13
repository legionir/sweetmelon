# NativeSDK

`js/native-sdk.js` defines the global `window.NativeSDK`. It wraps the low-level bridge (`window.Native`) that the app injects into the page. TypeScript definitions are in `js/native-sdk.d.ts`.

## Core methods

| Method | Description |
| --- | --- |
| `waitForReady(timeoutMs?)` | Resolves with the bridge info once the bridge is ready; rejects after the timeout (default 8000 ms) |
| `info()` | `{ initialized, pendingRequests, totalRequests, version }` |
| `call(plugin, method, args?, extra?)` | Calls one plugin method; returns a promise |
| `batch(requests, options?)` | Sends several calls in one round trip, e.g. `{ parallel: true }` |
| `on(event, handler)` | Subscribes to a native event; returns an unsubscribe function |
| `off(event, handler)` | Removes a handler |

## Plugin namespaces

Every plugin has a namespace with one function per method:

```javascript
await NativeSDK.storage.set('theme', 'dark');
const { ip } = await NativeSDK.networkInfo.getLocalIp();
const results = await NativeSDK.batch([
  { plugin: 'storage', method: 'get', args: { key: 'theme' } },
  { plugin: 'deviceInfo', method: 'getAppInfo', args: {} },
], { parallel: true });
```

The methods, arguments and return values of each plugin are in the [plugin reference](/plugins/overview).

## Errors

A failed call rejects with an object that has a stable `code` and a `message`:

| Code | Meaning |
| --- | --- |
| `PLUGIN_NOT_FOUND` | The plugin is not enabled in this build |
| `METHOD_NOT_FOUND` | The plugin has no such method |
| `INVALID_ARGS` | The arguments were rejected |
| `PERMISSION_DENIED` | The OS permission was not granted |
| `TIMEOUT`, `RATE_LIMIT_EXCEEDED`, `CANCELLED` | Execution limits |
| `EXECUTION_ERROR`, `NETWORK_ERROR`, `UNKNOWN` | The plugin failed |

```javascript
try {
  await NativeSDK.geolocation.getCurrentPosition();
} catch (e) {
  if (e.code === 'PERMISSION_DENIED') { /* ask the user */ }
}
```

Events are listed in [Events](/api/events). For retries, circuit breakers and an offline queue see [NativeResilience](/api/native-resilience).
