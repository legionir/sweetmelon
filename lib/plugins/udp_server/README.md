# UDP Server Plugin

Receive UDP datagrams and respond.

## Plugin Name
`udpServer`

## Methods

| Method | Description |
|--------|-------------|
| `start` | Bind UDP socket |
| `stop` | Close socket |
| `stopAll` | Close every socket; returns `{ stopped: <count> }` |
| `sendTo` | Send to specific address |
| `broadcast` | Send broadcast |
| `getServers` | List active sockets |
| `getStats` | Get statistics |
| `getInfo` | Returns plugin info: `{ name, version, activeServers }` |

### `start`
| Param | Type | Default |
|-------|------|---------|
| `port` | `number` | `0` |
| `host` | `string` | `"0.0.0.0"` |
| `id` | `string` | auto |
| `broadcast` | `bool` | `true` |
| `encoding` | `string` | `"utf8"` |

### `stop`
| Param | Type |
|-------|------|
| `id` | `string` ✅ (socket id; `serverId` accepted too) |

### `sendTo`
| Param | Type | Default |
|-------|------|---------|
| `serverId` | `string` | ✅ |
| `data` | `string` | ✅ |
| `host` | `string` | ✅ |
| `port` | `number` | ✅ |
| `encoding` | `string` | `"utf8"` |

### `broadcast`
| Param | Type |
|-------|------|
| `serverId` | `string` ✅ |
| `data` | `string` ✅ |
| `port` | `number` ✅ |

### `getStats`
| Param | Type |
|-------|------|
| `serverId` | `string` |
| `id` | `string` (alias for the socket id) |

## Events
| Event | Data |
|-------|------|
| `udpServer.started` | `{ serverId, port }` |
| `udpServer.data` | `{ serverId, data, senderAddress, senderPort, bytes }` |

## Usage
```javascript
// IoT sensor receiver
const srv = await NativeSDK.udpServer.start({ port: 5000 });

NativeSDK.on('udpServer.data', (packet) => {
  const sensor = JSON.parse(packet.data);
  console.log(`Sensor ${packet.senderAddress}: temp=${sensor.temp}°C`);
  
  // Respond
  NativeSDK.udpServer.sendTo(srv.id, 'ACK', packet.senderAddress, packet.senderPort);
});

// Discovery broadcast
await NativeSDK.udpServer.broadcast(srv.id, JSON.stringify({
  type: 'discover',
  name: 'MyDevice'
}), 5000);

// Stats
const stats = await NativeSDK.udpServer.getStats(srv.id);
console.log(`Packets: ${stats.packetCount}, Senders: ${stats.uniqueSenders}`);
```
