# TCP Server Plugin

Accept incoming TCP connections and exchange data.

## Plugin Name
`tcpServer`

## Methods

| Method | Description |
|--------|-------------|
| `start` | Start TCP server on port |
| `stop` | Stop specific server |
| `stopAll` | Stop all servers |
| `sendToClient` | Send data to specific client |
| `sendToAll` | Broadcast to all clients |
| `disconnectClient` | Disconnect a client |
| `disconnectAllClients` | Disconnect every client of a server (`serverId`); returns `{ disconnected: <count> }` |
| `getClients` | List connected clients |
| `getServers` | List running servers |
| `getInfo` | Returns plugin info: `{ name, version, activeServers }` |

### `start`
| Param | Type | Default |
|-------|------|---------|
| `port` | `number` | `0` (random) |
| `host` | `string` | `"0.0.0.0"` |
| `id` | `string` | auto |
| `maxClients` | `number` | `100` |
| `encoding` | `string` | `"utf8"` |

### `stop`
| Param | Type |
|-------|------|
| `id` | `string` ✅ (server id) |

### `sendToClient`
| Param | Type | Default |
|-------|------|---------|
| `serverId` | `string` | ✅ |
| `clientId` | `string` | ✅ |
| `data` | `any` | ✅ |
| `encoding` | `string` | `"utf8"` |

### `sendToAll`
| Param | Type |
|-------|------|
| `serverId` | `string` ✅ |
| `data` | `any` ✅ |
| `exclude` | `string` (client id to skip) |

### `disconnectClient`
| Param | Type |
|-------|------|
| `serverId` | `string` ✅ |
| `clientId` | `string` ✅ |

### `disconnectAllClients` / `getClients`
| Param | Type |
|-------|------|
| `serverId` | `string` ✅ |

## Events
| Event | Data |
|-------|------|
| `tcpServer.started` | `{ serverId, port }` |
| `tcpServer.clientConnected` | `{ serverId, clientId, remoteAddress }` |
| `tcpServer.data` | `{ serverId, clientId, data, bytes }` |
| `tcpServer.clientDisconnected` | `{ serverId, clientId }` |
| `tcpServer.clientError` | `{ serverId, clientId, error }` |

## Usage
```javascript
// Start server
const srv = await NativeSDK.tcpServer.start({ port: 9000, maxClients: 50 });
console.log('Server on port', srv.port);

// Handle data
NativeSDK.on('tcpServer.data', (msg) => {
  console.log(`[${msg.clientId}]: ${msg.data}`);
  // Echo back
  NativeSDK.tcpServer.sendToClient(msg.serverId, msg.clientId, 'ACK: ' + msg.data);
});

// Handle connections
NativeSDK.on('tcpServer.clientConnected', (info) => {
  NativeSDK.tcpServer.sendToClient(info.serverId, info.clientId, 'Welcome!');
});

// Broadcast to all
await NativeSDK.tcpServer.sendToAll(srv.id, 'Server announcement');

// List clients
const { clients } = await NativeSDK.tcpServer.getClients(srv.id);

// Stop
await NativeSDK.tcpServer.stop(srv.id);
```
