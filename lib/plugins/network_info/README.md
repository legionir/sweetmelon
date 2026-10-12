# Network Info Plugin

Network interfaces, IP addresses and basic network diagnostics.

## Plugin Name
`networkInfo`

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `getInterfaces` | — | `{ interfaces, count }` |
| `getIpAddresses` | — | `{ ipv4, ipv6, primary }` |
| `getLocalIp` | — | `{ ip, wifiIp, mobileIp, type }` |
| `getExternalIp` | — | `{ externalIp, source }` |
| `getGateway` | — | `{ gateway, available }` |
| `isPortOpen` | `host, port, timeoutMs?` | `{ host, port, open }` |
| `getHostname` | — | `{ hostname }` |
| `getInfo` | — | `{ name, version }` |

### Details

- **`getInterfaces`** — non-loopback interfaces with per-address details: `{ name, index, addresses: [{ address, type: "IPv4" | "IPv6", isLoopback, isLinkLocal, isMulticast, host }] }`.
- **`getLocalIp`** — best local IP, preferring WiFi interfaces (`wlan`/`wifi`/`en0`), then cellular (`rmnet`/`pdp`/`cellular`); `type` is `"wifi" | "mobile" | "other"`.
- **`getExternalIp`** — public IP via `api.ipify.org` with `ifconfig.me` fallback; requires internet access.
- **`getGateway`** — default gateway parsed from the routing table (`ip route`).
- **`isPortOpen`** — TCP connect probe; `timeoutMs` defaults to `3000`.

## Usage
```javascript
const { ip, type } = await NativeSDK.networkInfo.getLocalIp();
console.log(`Local IP ${ip} via ${type}`);

const { ipv4 } = await NativeSDK.networkInfo.getIpAddresses();
const { gateway } = await NativeSDK.networkInfo.getGateway();

const probe = await NativeSDK.networkInfo.isPortOpen('192.168.1.1', 443);
console.log('router https:', probe.open);

// Show QR/connect info to the user
const { externalIp } = await NativeSDK.networkInfo.getExternalIp();
```

## Notes
- Loopback and link-local addresses are excluded from `getInterfaces` and `getIpAddresses`
- Gateway detection depends on the platform `ip` command
