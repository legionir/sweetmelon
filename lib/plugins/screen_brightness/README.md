# Screen Brightness Plugin

Control device screen brightness.

## Plugin Name
`screenBrightness`

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `get` | — | `{ brightness: 0.8 }` |
| `set` | `brightness: 0.0-1.0` | `{ brightness, set }` |
| `reset` | — | `{ reset: true }` |
| `getSystem` | — | `{ brightness: 0.5 }` |
| `setAutoReset` | `enabled: bool` | `{ autoReset }` |
| `getInfo` | — | `{ name, version }` |

## Usage
```javascript
// Get current brightness
const { brightness } = await NativeSDK.screenBrightness.get();
console.log('Current:', Math.round(brightness * 100) + '%');

// Max brightness for QR scanner
await NativeSDK.screenBrightness.set(1.0);
const qr = await NativeSDK.qrScanner.scan();
await NativeSDK.screenBrightness.reset();  // restore

// Video player adaptive brightness
NativeSDK.on('app.lifecycle.change', async (state) => {
  if (state.state === 'resumed') {
    await NativeSDK.screenBrightness.set(0.7);
  }
});

// Auto-reset when app closes
await NativeSDK.screenBrightness.setAutoReset(true);
```
