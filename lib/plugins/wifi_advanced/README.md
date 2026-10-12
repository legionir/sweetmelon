# WiFi Advanced Plugin

Advanced WiFi details: scan, connection info, IP/DHCP configuration, signal strength and band.

## Plugin Name
`wifiAdvanced`

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `scan` | — | scan results (native) or connection info fallback |
| `getConnectionInfo` | — | `{ connected, ip, interfaceName, subnet, interfaces }` |
| `getIpConfig` | — | `{ ip, cidr, gateway, dns, broadcast }` |
| `getSignalStrength` | — | `{ level, quality, unit }` |
| `getDhcpInfo` | — | native DHCP info (falls back to `getIpConfig`) |
| `getFrequency` | — | `{ frequency, band, unit }` |
| `isWifiEnabled` | — | `{ enabled }` |
| `getInfo` | — | `{ name, version }` |

### Details

- **`scan`** — uses the native channel when available; otherwise falls back to `getConnectionInfo`.
- **`getConnectionInfo`** — detects the WiFi interface (`wlan`/`wifi`/`en0`), its IP, a `/24` subnet estimate and lists all interfaces.
- **`getSignalStrength`** — level in dBm with a `quality` label: `excellent` (≥ −50), `good` (≥ −60), `fair` (≥ −70), `weak` (≥ −80), `very_weak` below that.
- **`getFrequency`** — frequency in MHz; `band` is `"5GHz"` when above 5000 MHz, otherwise `"2.4GHz"`.

## Usage
```javascript
const info = await NativeSDK.wifiAdvanced.getConnectionInfo();
if (info.connected) {
  console.log(`WiFi IP ${info.ip} (${info.interfaceName})`);
}

const signal = await NativeSDK.wifiAdvanced.getSignalStrength();
console.log(`${signal.level} dBm → ${signal.quality}`);

const { band } = await NativeSDK.wifiAdvanced.getFrequency();
const cfg = await NativeSDK.wifiAdvanced.getIpConfig();
console.log(cfg.gateway, cfg.dns);
```

## Notes
- Several methods rely on platform commands (`ip`, `/proc/net/wireless`) or the native channel `sweetmelon/wifi_advanced`; unsupported platforms return graceful fallbacks instead of errors
- For basic enable/state/IP use the simpler `wifiManager` plugin
