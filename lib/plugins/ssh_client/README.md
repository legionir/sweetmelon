# SSH Client Plugin

SSH client for remote server management: command execution and SFTP file transfer.

## Plugin Name
`sshClient`

## Methods

| Method | Description |
|--------|-------------|
| `connect` | Open an SSH connection (password or private key) |
| `disconnect` | Close one connection by id |
| `execute` | Run a command and capture stdout |
| `upload` | SFTP upload (local → remote) |
| `download` | SFTP download (remote → local) |
| `getConnections` | List active connection ids |
| `disconnectAll` | Close every connection |
| `getInfo` | Plugin info (`activeConnections`) |

### `connect`
| Param | Type | Default |
|-------|------|---------|
| `host` | `string` | ✅ required |
| `username` | `string` | ✅ required |
| `port` | `number` | `22` |
| `password` | `string` | — |
| `privateKey` | `string` (PEM) | — |
| `id` | `string` | auto (`ssh_<ts>`) |

Provide `password` or `privateKey`. **Returns:** `{ connected, id, host, port }` — on failure `{ connected: false, error }`.

### `disconnect`
| Param | Type |
|-------|------|
| `id` | `string` ✅ |

### `execute`
| Param | Type |
|-------|------|
| `id` | `string` ✅ |
| `command` | `string` ✅ |

**Returns:** `{ success, command, output }`. Emits `ssh.output`.

### `upload`
| Param | Type |
|-------|------|
| `id` | `string` ✅ |
| `localPath` | `string` ✅ |
| `remotePath` | `string` ✅ |

**Returns:** `{ uploaded, localPath, remotePath, size }` — `{ uploaded: false, reason: "file_not_found" }` if the local file is missing.

### `download`
| Param | Type |
|-------|------|
| `id` | `string` ✅ |
| `remotePath` | `string` ✅ |
| `localPath` | `string` ✅ |

**Returns:** `{ downloaded, remotePath, localPath, size }`.

### `getConnections` / `disconnectAll`
**Returns:** `{ connections, count }` / `{ disconnected: <count> }`.

### `getInfo`
**Returns:** `{ name, version, activeConnections }`.

## Events
| Event | Data |
|-------|------|
| `ssh.output` | `{ connectionId, command, output }` |

## Usage
```javascript
const c = await NativeSDK.sshClient.connect('192.168.1.10', 'deploy', {
  port: 22,
  password: 'secret',
  id: 'prod'
});
if (!c.connected) throw new Error(c.error);

const res = await NativeSDK.sshClient.execute('prod', 'uptime && df -h');
console.log(res.output);

await NativeSDK.sshClient.upload('prod', '/data/build/app.zip', '/srv/releases/app.zip');
await NativeSDK.sshClient.download('prod', '/var/log/app.log', '/data/logs/app.log');

await NativeSDK.sshClient.disconnect('prod');
```

## Notes
- Calling `execute`/`upload`/`download` on an unknown id returns a result with `reason: "not_connected"` instead of throwing
- All connections are closed when the plugin is disposed
