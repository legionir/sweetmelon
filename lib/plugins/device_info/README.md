# Device Info Plugin

Get device hardware info and app package info.

## Plugin Name
`deviceInfo`

## Methods

### `getDeviceInfo`
Get device hardware information.

**Returns (Android):**
```json
{
  "platform": "android",
  "brand": "Samsung",
  "manufacturer": "samsung",
  "model": "SM-A525F",
  "isPhysicalDevice": true,
  "version": {
    "sdkInt": 33,
    "release": "13"
  },
  "supportedAbis": ["arm64-v8a", "armeabi-v7a"]
}
```

### `getAppInfo`
**Returns:**
```json
{
  "appName": "sweetmelon",
  "packageName": "com.core.sweetmelon",
  "version": "1.0.0",
  "buildNumber": "1"
}
```

### `getAll`
Returns both device and app info combined.

## Usage
```javascript
const { device, app } = await NativeSDK.deviceInfo.getAll();
console.log(`${device.brand} ${device.model} — v${app.version}`);
```
