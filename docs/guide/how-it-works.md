# How it works

```
JavaScript page (top frame only)
  window.NativeSDK  ->  window.Native.call / batch / on
        │  JSON messages over a WebView channel, with a per-page token
        ▼
WebViewHost (Flutter) ── navigation allow-list
        ▼
MessageBridge ── session, token check, size limit, protocol validation
        ▼
PluginManager ── permissions → rate limit → execution guard → cache → plugin
        ▼
Plugins (Dart) ── Android / iOS native APIs
```

## A call, step by step

1. The page calls `NativeSDK.<plugin>.<method>(...)`, which wraps `window.Native.call({ plugin, method, args })`.
2. The bridge parses the JSON message strictly and rejects it if the token is wrong or the message is too large.
3. The plugin manager checks the permission, the rate limit and the execution guard, and may answer from the cache.
4. The plugin loads on first use (lazy loading) and its `onCall(method, args)` runs.
5. The result, or an error with a stable code such as `PLUGIN_NOT_FOUND` or `PERMISSION_DENIED`, goes back to the page as a promise result.

Plugins can also emit events to the page, which you receive with `NativeSDK.on('connectivity.change', handler)`.

For the details of every layer and the security model, see [Architecture](/ARCHITECTURE) and [Security](/SECURITY).
