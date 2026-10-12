# Socket Plugin

Raw TCP client/server and UDP sockets with broadcast support.

## Plugin Name
`socket`

## Methods

| Method | Description |
|--------|-------------|
| `tcpConnect` | Open a TCP client connection |
| `tcpSend` | Send data on a connection (`utf8` or `base64`) |
| `tcpClose` | Close one connection |
| `tcpStartServer` | Start a TCP server (single instance) |
| `tcpStopServer` | Stop the TCP server |
| `udpBind` | Bind a UDP socket |
| `udpSend` | Send a UDP datagram |
| `udpBroadcast` | Broadcast a datagram to `255.255.255.255` |
| `udpClose` | Close a UDP socket |
| `getConnections` | List TCP connections, UDP sockets and server state |
| `closeAll` | Close every connection, socket and the server |
| `getInfo` | Counts and server state |

### `tcpConnect`
| Param | Type | Default |
|-------|------|---------|
| `host` | `string` | ✅ required |
| `port` | `number` | ✅ required |
| `id` | `string` | auto (`tcp_<ts>`) |
| `timeoutMs` | `number` | `10000` |
| `encoding` | `string` | `"utf8"` (`"base64"` supported) |

**Returns:** `{ connected, id, host, port, localPort }`.

### `tcpClose` / `udpClose`
| Param | Type |
|-------|------|
| `id` | `string` ✅ |

### `tcpSend`
| Param | Type | Default |
|-------|------|---------|
| `id` | `string` ✅ | — |
| `data` | `any` ✅ | — |
| `encoding` | `string` | `"utf8"` |

With `encoding: "base64"` a base64 string is decoded to raw bytes before sending. **Returns:** `{ sent, id }`.

### `tcpStartServer`
| Param | Type | Default |
|-------|------|---------|
| `port` | `number` | `0` (random) |
| `host` | `string` | `"0.0.0.0"` |

**Returns:** `{ started, alreadyRunning, port, host }`. Incoming clients get ids like `client_<ip>_<port>` and their data arrives as `socket.tcpServerData` events.

### `udpBind`
| Param | Type | Default |
|-------|------|---------|
| `port` | `number` | `0` (random) |
| `id` | `string` | auto (`udp_<ts>`) |
| `host` | `string` | `"0.0.0.0"` |
| `broadcast` | `bool` | `false` |

**Returns:** `{ bound, id, port }`.

### `udpSend` / `udpBroadcast`
| Param | Type |
|-------|------|
| `id` | `string` ✅ |
| `data` | `string` ✅ |
| `host` | `string` (`udpSend` only) |
| `port` | `number` ✅ |

**Returns:** `{ sent, bytes }` (broadcast adds `broadcast: true`).

### `getConnections`
**Returns:** `{ tcp: [{ id, host, port, sentBytes, receivedBytes }], udp: [{ id, port }], tcpServer: { port, clients } | null }`.

### `closeAll`
Closes all TCP connections, UDP sockets and the TCP server. Returns the closed counts.

### `getInfo`
**Returns:** `{ name, version, tcpConnections, udpSockets, tcpServerRunning }`.

## Events
| Event | Data |
|-------|------|
| `socket.tcpData` | `{ connectionId, data, encoding, bytes }` |
| `socket.tcpError` | `{ connectionId, error }` |
| `socket.tcpClosed` | `{ connectionId }` |
| `socket.tcpClientConnected` | `{ clientId, remoteAddress, remotePort }` |
| `socket.tcpServerData` | `{ clientId, data, bytes }` |
| `socket.tcpClientDisconnected` | `{ clientId }` |
| `socket.udpData` | `{ socketId, data, senderAddress, senderPort, bytes }` |

## Usage
```javascript
// TCP client
NativeSDK.on('socket.tcpData', (d) => console.log('recv:', d.data));
const { id } = await NativeSDK.socket.tcpConnect('192.168.1.20', 9000, { id: 'printer' });
await NativeSDK.socket.tcpSend('printer', 'HELLO\n');
await NativeSDK.socket.tcpClose('printer');

// TCP server
const srv = await NativeSDK.socket.tcpStartServer({ port: 9100 });
NativeSDK.on('socket.tcpServerData', (d) => console.log(d.clientId, d.data));
await NativeSDK.socket.tcpStopServer();

// UDP
const udp = await NativeSDK.socket.udpBind({ port: 5005, broadcast: true });
NativeSDK.on('socket.udpData', (d) => console.log(d.senderAddress, d.data));
await NativeSDK.socket.udpBroadcast(udp.id, 'discovery-probe', 5005);
await NativeSDK.socket.udpSend(udp.id, 'hi', '192.168.1.20', 5005);
await NativeSDK.socket.udpClose(udp.id);
```

## Notes
- Only one TCP server can run at a time; starting again returns `alreadyRunning: true`
- All sockets are closed when the plugin is disposed
