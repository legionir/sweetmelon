# Text Zoom Plugin

Adjust WebView text size for accessibility.

## Plugin Name
`textZoom`

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `get` | — | `{ zoom: 100 }` |
| `set` | `zoom: 50-300` | `{ zoom }` |
| `increase` | `step?: number` (default 10) | `{ zoom }` |
| `decrease` | `step?: number` (default 10) | `{ zoom }` |
| `reset` | — | `{ zoom: 100 }` |
| `getInfo` | — | `{ name, version, zoom, minZoom, maxZoom }` |

## Events
| Event | Data |
|-------|------|
| `textZoom.changed` | `{ zoom, timestamp }` |

## Usage
```javascript
// Accessibility settings page
const { zoom } = await NativeSDK.textZoom.get();
zoomSlider.value = zoom;

zoomSlider.oninput = async (e) => {
  await NativeSDK.textZoom.set(parseInt(e.target.value));
};

// Restore on app start
const savedZoom = await NativeSDK.storage.get('text_zoom');
if (savedZoom) await NativeSDK.textZoom.set(savedZoom);

// Save when changed
NativeSDK.on('textZoom.changed', async (data) => {
  await NativeSDK.storage.set('text_zoom', data.zoom);
});

// Quick +/- buttons
document.getElementById('zoomIn').onclick = () => NativeSDK.textZoom.increase(10);
document.getElementById('zoomOut').onclick = () => NativeSDK.textZoom.decrease(10);
```
