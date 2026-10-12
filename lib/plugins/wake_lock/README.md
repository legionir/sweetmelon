# Wake Lock Plugin

Keep device screen on during active operations.

## Plugin Name
`wakeLock`

## Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `enable` | Keep screen on | `{ enabled: true }` |
| `disable` | Allow screen to sleep | `{ enabled: false }` |
| `toggle` | Toggle current state | current state |
| `isEnabled` | Check current state | `{ enabled: bool }` |
| `getInfo` | Plugin info | `{ name, version, enabled }` |

## Usage
```javascript
// Video player — keep screen on
await NativeSDK.wakeLock.enable();
playVideo();

NativeSDK.on('videoPlayer.state', (state) => {
  if (!state.isPlaying) {
    NativeSDK.wakeLock.disable();
  }
});

// Navigation
await NativeSDK.wakeLock.enable();
startNavigation();

// QR Scanner
await NativeSDK.wakeLock.enable();
const result = await NativeSDK.qrScanner.scan();
await NativeSDK.wakeLock.disable();

// Always disable when done
window.addEventListener('beforeunload', () => {
  NativeSDK.wakeLock.disable();
});
```
