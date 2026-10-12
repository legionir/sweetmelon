# SSH Server Plugin

Command server with authentication and whitelisting.

## Plugin Name
`sshServer`

## Methods

| Method | Description |
|--------|-------------|
| `start` | Start server |
| `stop` | Stop server |
| `configure` | Set credentials and command rules |
| `addAllowedCommand` | Whitelist a command |
| `addBlockedCommand` | Block a command |
| `getClients` | List sessions |
| `disconnectClient` | Disconnect one session (`sessionId`) |
| `getCommandLog` | Get command history |
| `getInfo` | Returns plugin info: `{ name, version, running, port, clients, allowAllCommands }` |

### `configure`
| Param | Type | Default |
|-------|------|---------|
| `username` | `string` | `"admin"` |
| `password` | `string` | `"admin"` |
| `allowAllCommands` | `bool` | `false` |
| `allowedCommands` | `string[]` | — |

### `start`
| Param | Type | Default |
|-------|------|---------|
| `port` | `number` | `2222` |
| `host` | `string` | `"0.0.0.0"` |

### `addAllowedCommand` / `addBlockedCommand`
| Param | Type |
|-------|------|
| `command` | `string` ✅ |

### `disconnectClient` / `getCommandLog`
| Param | Type |
|-------|------|
| `sessionId` | `string` ✅ |

## Events
| Event | Data |
|-------|------|
| `sshServer.started` | `{ port }` |
| `sshServer.clientConnected` | `{ sessionId, remoteAddress }` |
| `sshServer.command` | `{ sessionId, command }` |
| `sshServer.commandResult` | `{ sessionId, command, exitCode }` |
| `sshServer.clientDisconnected` | `{ sessionId }` |

## Security
- Commands `rm -rf`, `format`, `mkfs`, `dd` are blocked by default
- Use whitelist mode for maximum security

## Usage
```javascript
// Configure with whitelist
await NativeSDK.sshServer.configure({
  username: 'admin',
  password: 'secure_password',
  allowAllCommands: false,
  allowedCommands: ['ls', 'cat', 'echo', 'date', 'whoami', 'uname', 'df', 'free']
});

// Start
const srv = await NativeSDK.sshServer.start({ port: 2222 });

const { ip } = await NativeSDK.networkInfo.getLocalIp();
console.log(`Connect via: telnet ${ip} ${srv.port}`);

// Monitor commands
NativeSDK.on('sshServer.command', (data) => {
  console.log(`[${data.sessionId}] ${data.command}`);
});

NativeSDK.on('sshServer.commandResult', (data) => {
  console.log(`Exit code: ${data.exitCode}`);
});

// View command log
const { log } = await NativeSDK.sshServer.getCommandLog('ssh_1');

// Stop
await NativeSDK.sshServer.stop();
```
