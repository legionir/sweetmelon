# WebSocket Plugin

Real-time bidirectional communication over WebSocket.

## Plugin Name
`websocket`

## Methods

### `connect`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `url` | `string` | ✅ | — |
| `id` | `string` | — | auto |
| `protocols` | `string[]` | — | — |
| `headers` | `object` | — | — |
| `autoReconnect` | `bool` | — | `false` |
| `maxReconnectAttempts` | `number` | — | `5` |
| `reconnectDelayMs` | `number` | — | `3000` |
| `pingIntervalMs` | `number` | — | — |

**Returns:**
```json
{ "id": "ws_123", "connected": true, "lensDirection": "back" }
```

### `disconnect`
| Param | Type | Required |
|-------|------|----------|
| `id` | `string` | ✅ |
| `code` | `number` | — |
| `reason` | `string` | — |

### `send`
| Param | Type | Required |
|-------|------|----------|
| `id` | `string` | ✅ |
| `data` | `any` | ✅ |

### `sendJson`
| Param | Type | Required |
|-------|------|----------|
| `id` | `string` | ✅ |
| `data` | `object` | ✅ |

### `getState` — `id` (string ✅)
### `getConnections` / `disconnectAll`

### `getInfo`

**Returns:** `{ name, version, activeConnections }`

## Events
| Event | Data |
|-------|------|
| `websocket.connected` | `{ id, url }` |
| `websocket.message` | `{ id, data, type, messageNumber }` |
| `websocket.disconnected` | `{ id, closeCode, closeReason }` |
| `websocket.error` | `{ id, error, type }` |
| `websocket.reconnecting` | `{ id, attempt, maxAttempts, delayMs }` |

## Usage
```javascript
// Connect
const { id } = await NativeSDK.websocket.connect({
  url: 'wss://echo.example.com',
  autoReconnect: true,
  maxReconnectAttempts: 5
});

// Listen
NativeSDK.on('websocket.message', (data) => {
  console.log('Received:', data.data);
});

NativeSDK.on('websocket.disconnected', (data) => {
  console.log('Disconnected:', data.closeCode);
});

// Send
await NativeSDK.websocket.sendJson(id, { action: 'ping' });
await NativeSDK.websocket.send(id, 'Hello!');

// Disconnect
await NativeSDK.websocket.disconnect(id);
```
