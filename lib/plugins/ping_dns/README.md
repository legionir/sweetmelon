# Ping & DNS Plugin

Ping hosts, resolve DNS names and run traceroute for connectivity diagnostics.

## Plugin Name
`pingDns`

## Methods

| Method | Description |
|--------|-------------|
| `ping` | ICMP ping with parsed RTT stats |
| `dnsLookup` | Resolve a hostname to addresses |
| `reverseDns` | Reverse-resolve an IP to a hostname |
| `traceroute` | Trace hops to a host |
| `isReachable` | TCP reachability probe |
| `getInfo` | Plugin info |

### `ping`
| Param | Type | Default |
|-------|------|---------|
| `host` | `string` | ✅ required |
| `count` | `number` | `4` |
| `timeoutMs` | `number` | `5000` |

**Returns:** `{ host, reachable, count, avgMs, minMs, maxMs, packetLoss, output }`. Falls back to a TCP reachability probe when the `ping` binary is unavailable.

### `dnsLookup`
| Param | Type |
|-------|------|
| `host` | `string` ✅ |

**Returns:** `{ host, resolved, addresses: [{ address, host, type, isLoopback }], primary, count }`.

### `reverseDns`
| Param | Type |
|-------|------|
| `ip` | `string` ✅ |

**Returns:** `{ ip, hostname, resolved }`.

### `traceroute`
| Param | Type | Default |
|-------|------|---------|
| `host` | `string` | ✅ required |
| `maxHops` | `number` | `15` |

**Returns:** `{ host, hops: [{ hop, host, ip, rttMs, timeout? }], hopCount, completed }`.

### `isReachable`
| Param | Type | Default |
|-------|------|---------|
| `host` | `string` | ✅ required |
| `port` | `number` | `80` |
| `timeoutMs` | `number` | `3000` |

**Returns:** `{ host, port, reachable }`.

### `getInfo`
**Returns:** `{ name, version }`.

## Usage
```javascript
const ping = await NativeSDK.pingDns.ping('8.8.8.8', { count: 3 });
console.log(`avg ${ping.avgMs} ms, loss ${ping.packetLoss}%`);

const dns = await NativeSDK.pingDns.dnsLookup('example.com');
console.log('resolved:', dns.primary);

const trace = await NativeSDK.pingDns.traceroute('example.com', { maxHops: 10 });
trace.hops.forEach((h) => console.log(h.hop, h.host, h.rttMs));

const up = await NativeSDK.pingDns.isReachable('api.example.com', 443);
```

## Notes
- `ping` and `traceroute` shell out to the platform binaries; timeouts are raised (30s/60s) on the bridge side
