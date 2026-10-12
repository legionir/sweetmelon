# Bluetooth BLE Plugin

Scan, connect, read/write BLE characteristics.

## Plugin Name
`bluetooth`

## Methods

| Method | Args | Description |
|--------|------|-------------|
| `isAvailable` | — | Check BLE support |
| `isOn` | — | Check if Bluetooth is enabled |
| `startScan` | `timeoutSeconds` (default 10) | Start BLE scan |
| `stopScan` | — | Stop scanning |
| `connect` | `deviceId` ✅, `timeoutSeconds` (default 15), `autoConnect` (default false) | Connect to device |
| `disconnect` | `deviceId` ✅ | Disconnect from device |
| `discoverServices` | `deviceId` ✅ | List services & characteristics |
| `readCharacteristic` | `deviceId` ✅, `serviceUuid` ✅, `characteristicUuid` ✅ | Read value |
| `writeCharacteristic` | `deviceId` ✅, `serviceUuid` ✅, `characteristicUuid` ✅, `value` ✅ (base64), `withResponse` (default true) | Write value |
| `getConnectedDevices` | — | List connected devices |
| `getInfo` | — | Returns plugin info: `{ name, version, scanning, connectedDevices }` |

## Events
- `bluetooth.deviceFound` — `{ deviceId, name, rssi }`
- `bluetooth.connectionState` — `{ deviceId, state, connected }`

## Usage
```javascript
await NativeSDK.bluetooth.startScan({ timeoutSeconds: 10 });
NativeSDK.on('bluetooth.deviceFound', async (device) => {
  if (device.name === 'MySensor') {
    await NativeSDK.bluetooth.connect(device.deviceId);
    const services = await NativeSDK.bluetooth.discoverServices(device.deviceId);
    const value = await NativeSDK.bluetooth.readCharacteristic({
      deviceId: device.deviceId,
      serviceUuid: '180d',
      characteristicUuid: '2a37'
    });
  }
});
```
