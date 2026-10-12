# FTP Server Plugin

Share files over local network via FTP.

## Plugin Name
`ftpServer`

## Methods

| Method | Description |
|--------|-------------|
| `start` | Start FTP server |
| `stop` | Stop server |
| `configure` | Set credentials |
| `getClients` | List connected clients |
| `disconnectClient` | Disconnect one client (`sessionId`) |
| `getStats` | Server statistics |
| `getInfo` | Returns plugin info: `{ name, version, running, port, rootDir, clients }` |

### `configure`
| Param | Type | Default |
|-------|------|---------|
| `username` | `string` | `"anonymous"` |
| `password` | `string` | `""` |
| `allowAnonymous` | `bool` | `true` |

### `start`
| Param | Type | Default |
|-------|------|---------|
| `rootDir` | `string` | ✅ required |
| `port` | `number` | `2121` |
| `host` | `string` | `"0.0.0.0"` |

### `disconnectClient`
| Param | Type |
|-------|------|
| `sessionId` | `string` ✅ |

## Events
| Event | Data |
|-------|------|
| `ftpServer.started` | `{ port, rootDir }` |
| `ftpServer.clientConnected` | `{ sessionId, remoteAddress }` |
| `ftpServer.clientDisconnected` | `{ sessionId }` |
| `ftpServer.fileUploaded` | `{ sessionId, file, size }` |
| `ftpServer.fileDownloaded` | `{ sessionId, file, size }` |
| `ftpServer.command` | `{ sessionId, command }` |

## Usage
```javascript
// Get a directory to share
const dirs = await NativeSDK.fileSystem.getDirectories();
const shareDir = dirs.documents + '/shared';

// Configure
await NativeSDK.ftpServer.configure({
  username: 'admin',
  password: 'secret123',
  allowAnonymous: false
});

// Start
const srv = await NativeSDK.ftpServer.start(shareDir, { port: 2121 });
console.log('FTP Server:', srv.url);

// Get local IP for sharing
const { ip } = await NativeSDK.networkInfo.getLocalIp();
console.log(`Connect: ftp://${ip}:${srv.port}`);

// Monitor
NativeSDK.on('ftpServer.fileUploaded', (data) => {
  console.log(`File received: ${data.file} (${data.size} bytes)`);
});

// Stop
await NativeSDK.ftpServer.stop();
```
