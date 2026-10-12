# Volume Buttons Plugin

Capture hardware volume button presses.

## Plugin Name
`volumeButtons`

## Methods

| Method | Returns |
|--------|---------|
| `startListening` | `{ started: bool }` |
| `stopListening` | `{ stopped: bool }` |
| `isListening` | `{ listening: bool }` |
| `getInfo` | `{ name, version, listening }` |

## Events
| Event | Data |
|-------|------|
| `volume.pressed` | `{ direction: "up"/"down", timestamp }` |

## Use Cases
- Camera shutter trigger
- Barcode scanner trigger
- Presentation slide control
- Game controls

## Usage
```javascript
// Camera shutter with volume button
await NativeSDK.volumeButtons.startListening();
NativeSDK.on('volume.pressed', async (data) => {
  if (data.direction === 'up') {
    await NativeSDK.haptic.lightImpact();
    const photo = await NativeSDK.camera.takePhoto({ quality: 90 });
    displayPhoto(photo.path);
  }
});

// QR scanner trigger
NativeSDK.on('volume.pressed', async () => {
  if (scannerActive) {
    const result = await NativeSDK.qrScanner.scan();
    handleScan(result);
  }
});

// Stop when leaving scanner
await NativeSDK.volumeButtons.stopListening();
```
