# Camera Preview Plugin

Live camera preview with full control.

## Plugin Name
`cameraPreview`

## Methods

### `start`
| Param | Type | Default |
|-------|------|---------|
| `cameraIndex` | `number` | `0` (back) |
| `resolution` | `string` | `"high"` |
| `enableAudio` | `bool` | `true` |

**resolution:** `low`, `medium`, `high`, `veryHigh`, `ultraHigh`, `max`

### `stop`
### `takePhoto`
| Param | Type | Default |
|-------|------|---------|
| `fileName` | `string` | auto |

### `startRecording` / `stopRecording`
### `switchCamera` — Toggle front/back
### `setFlashMode`
| Param | Type | Required |
|-------|------|----------|
| `mode` | `string` | ✅ |

**Modes:** `off`, `auto`, `always`, `torch`

### `setZoomLevel`
| Param | Type |
|-------|------|
| `zoom` | `number` |

### `getMinZoomLevel` / `getMaxZoomLevel`
### `setFocusPoint`
| Param | Type |
|-------|------|
| `x` | `number` (0-1) |
| `y` | `number` (0-1) |

### `setExposureMode` — `mode` required (values: auto, locked)
### `getAvailableCameras` / `getState`

### `getInfo`

**Returns:** `{ name, version, camerasCount, initialized, recording }`

## Events
| Event | Data |
|-------|------|
| `cameraPreview.started` | `{ cameraIndex, lensDirection }` |
| `cameraPreview.stopped` | — |
| `cameraPreview.photoTaken` | `{ path, fileName, size }` |
| `cameraPreview.recordingStarted` | — |
| `cameraPreview.recordingStopped` | `{ path, size }` |

## Usage
```javascript
// Initialize camera
const cameras = await NativeSDK.cameraPreview.getAvailableCameras();
console.log('Cameras:', cameras.count);

await NativeSDK.cameraPreview.start({
  cameraIndex: 0,
  resolution: 'high'
});

// Take photo
const photo = await NativeSDK.cameraPreview.takePhoto({
  fileName: 'avatar_' + Date.now()
});
displayPreview(photo.path);

// Zoom
const { level: maxZoom } = await NativeSDK.cameraPreview.getMaxZoomLevel();
zoomSlider.max = maxZoom;
zoomSlider.oninput = (e) => NativeSDK.cameraPreview.setZoomLevel(+e.target.value);

// Flash toggle
let flashOn = false;
flashBtn.onclick = () => {
  flashOn = !flashOn;
  NativeSDK.cameraPreview.setFlashMode(flashOn ? 'torch' : 'off');
};

// Record video
await NativeSDK.cameraPreview.startRecording();
// ... user records ...
const video = await NativeSDK.cameraPreview.stopRecording();
console.log('Video saved:', video.path);

// Cleanup
await NativeSDK.cameraPreview.stop();
```
