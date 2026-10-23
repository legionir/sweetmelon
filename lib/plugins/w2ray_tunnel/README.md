# w2ray Tunnel Plugin

Connects the phone to a **w2ray tunnel server** (the WebSocket tunnel in
[`src/tunnel`](https://github.com/legionir/w2ray) of the w2ray project) and
offers two things:

1. **VPN**: all traffic (or the traffic of chosen apps) leaves through the server.
2. **Sharing**: a SOCKS5 proxy on a port of your choice, so other devices on
   your Wi-Fi or hotspot use *your phone's connection to the server*.

Android only. The plugin is off by default; turn it on in `sweetmelon.yaml`
(`w2ray_tunnel: enabled: true`). Only then does the build contain the native
module (`android/w2ray_tunnel`: VPN service, tunnel engine and
[hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel)).

## Plugin Name
`w2rayTunnel`

## How it works

```
apps ──► TUN ──► hev-socks5-tunnel ──► 127.0.0.1:<random> (SOCKS5, random password)
                                              │
other devices ──► <phone>:<share port> ───────┤  tunnel engine: one WebSocket per connection,
                      (SOCKS5, optional login) │  a few authenticated ones kept ready
                                              ▼
                                       w2ray server ──► internet
```

- The tunnel carries **TCP only**. DNS is answered by hev's mapped DNS
  (`remoteDns`, default), so names resolve on the server side. UDP datagrams
  to port 53 are relayed as DNS over TCP; other UDP (QUIC, games, VoIP) is
  dropped and apps fall back to TCP.
- The app itself is excluded from the VPN, so its connection to the server
  never loops.
- A wrong password stops the connection at once and is **not retried**: the
  server bans an address after 5 failures for 15 minutes.

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `prepare` | — | `true` when the VPN permission is granted (shows the system dialog if needed) |
| `start` | `config` (object, see below) | `true`. Progress arrives as `w2rayTunnel.state` |
| `stop` | — | `true` |
| `status` | — | `{ state, message, mode, label, server, connectedAt, rx, tx, rxRate, txRate, connections, share, running }` |
| `logs` | — | `[{ level, time, message }]` (last 1000) |
| `clearLogs` | — | `true` |
| `setShare` | `share` (object) | status. Starts, changes or stops sharing while connected |
| `addresses` | — | `[{ interface, address, ipv6, kind }]`: where other devices can reach the phone (`kind`: `wifi`, `hotspot`, `usb`, `bluetooth`, `mobile`, `other`) |
| `apps` | — | `[{ packageName, appName, isSystem }]` for split tunnelling |
| `appIcon` | `packageName`, `size?` (48) | Base64 PNG or `null` |
| `test` | `config`, `deep?` | `{ serverMs, targetMs? }`: reaches the server (password included) without a VPN |
| `netInfo` | — | `{ ip, country, countryCode, region, city, isp, org, timezone, serverMs, targetMs }` as seen from the server; needs a running tunnel |
| `openVpnSettings` | — | opens Android's VPN settings (Always-on VPN and "Block connections without VPN") |
| `getInfo` | — | `{ name, version, native: { version, sdk, abi, nativeLoaded } }` |

States: `idle`, `connecting`, `connected`, `reconnecting`, `disconnecting`, `error`.

## `config`

Server (one of `url` or `serverHost`):

| Key | Default | |
|-----|---------|--|
| `url` | | `wss://host:4431/api/stream` (the `TUNNEL_URL` of the w2ray client) |
| `serverHost`, `serverPort`, `useTls`, `wsPath` | `443`, `true`, `/` | same, field by field |
| `password` | required | the tunnel password |
| `sni` | host | TLS server name |
| `hostHeader` | `sni` or host | HTTP `Host` of the upgrade request |
| `allowInsecure` | `false` | accept any certificate |
| `connectTimeoutMs`, `handshakeTimeoutMs` | `15000` | |
| `pingIntervalSec` | `45` | WebSocket keep-alive (0 = off) |
| `idleTimeoutMs` | `900000` | close connections silent for this long (0 = never) |
| `bufferSize` | `32768` | |
| `warmPool` | `2` | authenticated tunnels kept ready (0 = off) |
| `maxConnections` | `1024` | |
| `preferIpv6` | `false` | |

Mode and VPN:

| Key | Default | |
|-----|---------|--|
| `mode` | `vpn` | `vpn`, or `proxy` (sharing only, no VPN interface) |
| `label` | server host | name in the notification |
| `tunnelMtu` | `8500` | |
| `enableIpv4`, `enableIpv6` | `true`, `false` | |
| `blockIpv6` | `true` | with IPv6 off, route IPv6 into the tunnel and drop it so apps cannot leak around the VPN |
| `globalMode` | `true` | `false`: only the mapped DNS range goes through the tunnel |
| `bypassLan` | `false` | keep private networks (10/8, 172.16/12, 192.168/16…) outside the VPN |
| `remoteDns` | `true` | resolve names on the server side (hev mapped DNS) |
| `mapDnsAddress`, `mapDnsPort`, `mapDnsNetwork`, `mapDnsNetmask`, `mapDnsCacheSize` | `198.18.0.2`, `53`, `100.64.0.0`, `255.192.0.0`, `10000` | |
| `dnsIpv4`, `dnsIpv6` | `8.8.8.8`, `2001:4860:4860::8888` | used when `remoteDns` is `false` |
| `udpDns` | `true` | relay DNS datagrams as DNS over TCP |
| `icmpReply` | `false` | answer pings locally |
| `tcpBufferSize`, `taskStackSize`, `maxSessionCount` | `65536`, `86016`, `0` | hev tuning |
| `logLevel` | `warn` | hev: `debug`, `info`, `warn`, `error` |
| `splitMode` | `off` | `off`, `exclude` (listed apps bypass the VPN), `include` (only listed apps use it) |
| `apps` | `[]` | package names for `splitMode` |
| `excludeGoogleServices` | `false` | Google Play services bypass the VPN (push notifications) |
| `killSwitch` | `true` | while the server is unreachable keep the interface up and block traffic; `false` releases the connection after 45 s |
| `notification` | | `{ connecting, connected, reconnecting, disconnect, download, upload }` texts |

Sharing, in `config.share` or as the `share` argument of `setShare`:

| Key | Default | |
|-----|---------|--|
| `enabled` | `false` | |
| `bind` | `0.0.0.0` | address to listen on |
| `port` | `1080` | |
| `authEnabled`, `username`, `password` | `false` | SOCKS5 login (RFC 1929). Five wrong logins ban an address for 5 minutes |
| `maxConnections` | `256` | |
| `allowPrivate` | `false` | allow destinations on private networks; loopback, link-local and multicast are always refused |

Share a connection with no VPN on this phone: `mode: 'proxy'` with
`share.enabled: true`. Anyone who can reach the port can use your server, so
turn on `authEnabled` unless the network is yours alone.

## Events
- `w2rayTunnel.state` — `{ state, message, mode, server, connectedAt }`
- `w2rayTunnel.log` — `{ level: D|I|W|E, time, message }`
- `w2rayTunnel.stats` — every second: `{ rx, tx, rxRate, txRate, uptime, connections, share }`. `tx` is what the device sent, `rx` what it received.

`share` is `{ enabled, bind, port, auth, username, clients, connections, totalConnections, rx, tx }` (`rx`/`tx` of the shared clients; `tx` is what they sent).

## Errors
Native failures arrive with `details.nativeCode`: `PERMISSION` (VPN permission
missing), `CONFIG` (bad settings, message says which), `TUNNEL` (server
unreachable or refused the password), `NOT_RUNNING`, `UNAVAILABLE` (module not
in this build).

## Usage
```javascript
await NativeSDK.w2rayTunnel.prepare();            // system dialog, once
NativeSDK.on('w2rayTunnel.state', (s) => console.log(s.state, s.message));
await NativeSDK.w2rayTunnel.start({
  config: {
    url: 'wss://example.com:4431/api/stream',
    password: 'secret',
    share: { enabled: true, port: 1080, authEnabled: true, username: 'me', password: 'x' }
  }
});
const { share } = await NativeSDK.w2rayTunnel.status();
const addresses = await NativeSDK.w2rayTunnel.addresses();   // show socks5://<address>:1080
```

## Always-on VPN
The last configuration is kept on the device, so Android can start the service
itself (Settings → VPN → ⚙ → *Always-on VPN* and *Block connections without
VPN*). That is the system-level kill switch; `openVpnSettings` opens the page.
