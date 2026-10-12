# HTTP Server Plugin

Run one or more local HTTP servers with static routes, static directory
serving and CORS support.

## Plugin Name
`httpServer`

## Methods

| Method | Description |
|--------|-------------|
| `start` | Start a server (optionally named) |
| `stop` | Stop one server by id |
| `stopAll` | Stop every running server |
| `addRoute` | Register a static route response |
| `removeRoute` | Remove routes for a path |
| `serveDirectory` | Serve a directory as static files (SPA fallback) |
| `getServers` | List running servers and counters |
| `getRequests` | Request count for one server |
| `getInfo` | Plugin info (`activeServers`) |

### `start`
| Param | Type | Default |
|-------|------|---------|
| `id` | `string` | auto (`server_<ts>`) |
| `port` | `number` | `0` (random) |
| `host` | `string` | `"0.0.0.0"` |
| `cors` | `bool` | `true` |

**Returns:** `{ started, alreadyRunning, id, port, url }` — starting an id that already exists returns the existing server.

### `stop`
| Param | Type |
|-------|------|
| `id` | `string` ✅ |

**Returns:** `{ stopped, id }` or `{ stopped: false, reason: "not_found" }`.

### `addRoute`
| Param | Type | Default |
|-------|------|---------|
| `serverId` | `string` ✅ | — |
| `method` | `string` | `"GET"` |
| `path` | `string` ✅ | — |
| `statusCode` | `number` | `200` |
| `contentType` | `string` | `"application/json"` |
| `response` | `any` | echo of the request |

Route paths support exact match, trailing wildcards (`/api/*`) and `:param` segments (`/users/:id`). When no `response` is given, the route echoes `{ path, method, params, query, body }`.

**Returns:** `{ added, method, path }`.

### `removeRoute`
| Param | Type |
|-------|------|
| `serverId` | `string` ✅ |
| `path` | `string` ✅ |

**Returns:** `{ removed, path }`.

### `serveDirectory`
| Param | Type |
|-------|------|
| `serverId` | `string` ✅ |
| `directory` | `string` ✅ |

**Returns:** `{ set, directory, url }`. Missing files fall back to `index.html` (SPA mode); `..` paths are rejected with 403.

### `getServers`
**Returns:** `{ servers: [{ id, port, requestCount, hasStaticDir, routeCount }], count }`.

### `getRequests`
| Param | Type |
|-------|------|
| `serverId` | `string` ✅ — the key the handler reads |
| `id` | accepted by validation as an alias |

**Returns:** `{ found, requestCount }`.

### `getInfo`
**Returns:** `{ name, version, activeServers }`.

## Events
| Event | Data |
|-------|------|
| `httpServer.started` | `{ serverId, port, host }` |
| `httpServer.error` | `{ serverId, error }` |
| `httpServer.request` | `{ serverId, method, path, query, headers, body, remoteAddress }` |

`httpServer.request` fires for requests that matched no route and no static directory — useful for implementing dynamic handlers in JS. Unmatched requests otherwise answer 404 JSON.

## Usage
```javascript
const srv = await NativeSDK.httpServer.start({ id: 'api', port: 8080 });
console.log('Server at', srv.url);

// Static JSON endpoint
await NativeSDK.httpServer.addRoute('api', 'GET', '/status', { ok: true, ts: Date.now() });

// Param route
await NativeSDK.httpServer.addRoute('api', 'GET', '/users/:id', { id: 'from-param' });

// Serve a folder (SPA fallback to index.html)
const dirs = await NativeSDK.fileSystem.getDirectories();
await NativeSDK.httpServer.serveDirectory('api', dirs.documents + '/www');

// Dynamic handling from JS
NativeSDK.on('httpServer.request', async (req) => {
  console.log(req.method, req.path, req.body);
});

console.log(await NativeSDK.httpServer.getServers());
await NativeSDK.httpServer.stop('api');
```

## Notes
- CORS is enabled per server by default and answers preflight `OPTIONS`
- Servers are closed automatically when the plugin is disposed
