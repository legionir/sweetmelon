# WiFi Manager Plugin

Get WiFi connection information.

## Plugin Name
`wifiManager`

## Methods

### `getConnectionInfo`
**Returns:**
```json
{
  "connected": true,
  "ip": "192.168.1.100",
  "interfaceName": "wlan0",
  "interfaces": [...]
}
```

### `getIpAddress`
**Returns:** `{ ips: ["192.168.1.100"], primary: "192.168.1.100" }`

### `isEnabled`
**Returns:** `{ enabled: bool }`

### `getInfo`

**Returns:** `{ name, version, platform }`

## Usage
```javascript
const info = await NativeSDK.wifiManager.getConnectionInfo();
if (info.connected) {
  console.log('IP:', info.ip);
  document.getElementById('ip').textContent = info.ip;
}

// Network-dependent features
const { enabled } = await NativeSDK.wifiManager.isEnabled();
if (!enabled) {
  await NativeSDK.nativeSettings.openWifi();
}
```
