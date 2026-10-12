# FTP Client Plugin

FTP client for file transfer with remote servers (passive mode).

## Plugin Name
`ftpClient`

## Methods

| Method | Description |
|--------|-------------|
| `connect` | Open control connection to a server |
| `login` | Authenticate (anonymous by default) |
| `listFiles` | List directory entries (parsed) |
| `downloadFile` | Download a remote file (binary) |
| `uploadFile` | Upload a local file (binary) |
| `deleteFile` | Delete a remote file |
| `makeDirectory` | Create a remote directory |
| `removeDirectory` | Remove a remote directory |
| `getCurrentDirectory` | Print working directory (PWD) |
| `changeDirectory` | Change working directory (CWD) |
| `disconnect` | Quit and close the connection |
| `getInfo` | Connection state |

### `connect`
| Param | Type | Default |
|-------|------|---------|
| `host` | `string` | ✅ required |
| `port` | `number` | `21` |
| `timeoutMs` | `number` | `10000` |

**Returns:** `{ connected, host, port, response }` — on failure `{ connected: false, error }`.

### `login`
| Param | Type | Default |
|-------|------|---------|
| `username` | `string` | `"anonymous"` |
| `password` | `string` | `""` |

**Returns:** `{ loggedIn, response }`.

### `listFiles`
| Param | Type | Default |
|-------|------|---------|
| `path` | `string` | `"."` |

**Returns:** `{ files, count, path }` where each file is `{ permissions, type: "file" | "directory", size, date, name }` (or `{ raw }` for unparseable lines).

### `downloadFile`
| Param | Type |
|-------|------|
| `remotePath` | `string` ✅ |
| `localPath` | `string` ✅ |

**Returns:** `{ downloaded, localPath, size }`. Emits `ftp.downloaded`.

### `uploadFile`
| Param | Type |
|-------|------|
| `localPath` | `string` ✅ |
| `remotePath` | `string` ✅ |

**Returns:** `{ uploaded, remotePath, size }` — `{ uploaded: false, reason: "file_not_found" }` if the local file is missing. Emits `ftp.uploaded`.

### `deleteFile` / `makeDirectory` / `removeDirectory` / `changeDirectory`
| Param | Type |
|-------|------|
| `path` | `string` ✅ |

**Returns:** `{ deleted | created | removed | changed, response }`.

### `getCurrentDirectory`
**Returns:** `{ path, response }`.

### `disconnect`
**Returns:** `{ disconnected }`.

### `getInfo`
**Returns:** `{ name, version, connected, host, port }`.

## Events
| Event | Data |
|-------|------|
| `ftp.downloaded` | `{ remotePath, localPath, size }` |
| `ftp.uploaded` | `{ localPath, remotePath, size }` |

## Notes
- Uses passive mode (`PASV`) and binary transfer (`TYPE I`) for data connections
- Calling a method while disconnected returns a result with `reason: "not_connected"` instead of throwing
- Connections are closed automatically when the plugin is disposed

## Usage
```javascript
const conn = await NativeSDK.ftpClient.connect('192.168.1.50', { port: 21 });
if (!conn.connected) throw new Error(conn.error);

await NativeSDK.ftpClient.login('admin', 'secret');

const { files } = await NativeSDK.ftpClient.listFiles('.');
files.forEach((f) => console.log(f.type, f.name, f.size));

NativeSDK.on('ftp.downloaded', (d) => console.log(`Saved ${d.size} bytes to ${d.localPath}`));
await NativeSDK.ftpClient.downloadFile('/reports/daily.csv', '/data/downloads/daily.csv');

await NativeSDK.ftpClient.uploadFile('/data/uploads/photo.jpg', '/incoming/photo.jpg');

await NativeSDK.ftpClient.changeDirectory('/incoming');
console.log('cwd:', await NativeSDK.ftpClient.getCurrentDirectory());

await NativeSDK.ftpClient.disconnect();
```
