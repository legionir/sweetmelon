# WebSocket Server Plugin

WebSocket server for P2P / LAN communication between devices and web clients.

## Plugin Name
`websocketServer`

## Methods

| Method | Description |
|--------|-------------|
| `start` | Start the server |
| `stop` | Stop the server and disconnect all clients |
| `sendToClient` | Send to one client |
| `sendToAll` | Broadcast to all clients (optionally excluding one) |
| `disconnectClient` | Disconnect one client |
| `getClients` | List connected client ids |
| `getInfo` | `{ name, version, running, port, clientCount }` |

### `start`
| Param | Type | Default |
|-------|------|---------|
| `port` | `number` | `0` (random) |
| `host` | `string` | `"0.0.0.0"` |

**Returns:** `{ started, alreadyRunning, port, url }` — plain HTTP requests to the port answer with a JSON status page instead of upgrading.

### `sendToClient`
| Param | Type |
|-------|------|
| `clientId` | `string` ✅ |
| `data` | `any` ✅ |

Maps/lists are JSON-encoded before sending. **Returns:** `{ sent, clientId }`.

### `sendToAll`
| Param | Type |
|-------|------|
| `data` | `any` ✅ |
| `exclude` | `string` (client id) | — |

**Returns:** `{ sent, totalClients }`.

### `disconnectClient`
| Param | Type |
|-------|------|
| `clientId` | `string` ✅ |

**Returns:** `{ disconnected, clientId }`.

### `getClients`
**Returns:** `{ clients, count }`.

## Events
| Event | Data |
|-------|------|
| `wsServer.started` | `{ port, host }` |
| `wsServer.clientConnected` | `{ clientId, remoteAddress, remotePort, totalClients }` |
| `wsServer.clientDisconnected` | `{ clientId, totalClients }` |
| `wsServer.message` | `{ clientId, data, type: "text" \| "binary" }` |

Text frames are JSON-parsed when possible; binary frames arrive base64-encoded in `data`.

## Usage
```javascript
const srv = await NativeSDK.websocketServer.start({ port: 9200 });
console.log('ws at', srv.url);

NativeSDK.on('wsServer.clientConnected', (c) => {
  NativeSDK.websocketServer.sendToClient(c.clientId, { hello: c.clientId });
});

NativeSDK.on('wsServer.message', (m) => {
  // Echo to everyone else
  NativeSDK.websocketServer.sendToAll({ from: m.clientId, data: m.data }, m.clientId);
});

const { clients } = await NativeSDK.websocketServer.getClients();
await NativeSDK.websocketServer.stop();
```

## Notes
- Only one server instance runs at a time; starting again returns `alreadyRunning: true`
- Client ids are assigned as `client_1`, `client_2`, …
- The server is stopped automatically when the plugin is disposed
