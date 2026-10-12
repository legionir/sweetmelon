# Media Manager Plugin

Save media files to device gallery.

## Plugin Name
`mediaManager`

## Methods

### `saveImageToGallery`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `path` | `string` | ✅ | — |
| `quality` | `number` 0-100 | — | `100` |

### `saveVideoToGallery`
| Param | Type | Required |
|-------|------|----------|
| `path` | `string` | ✅ |

### `saveFileToGallery`
| Param | Type | Required |
|-------|------|----------|
| `path` | `string` | ✅ |

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Take photo and save to gallery
const photo = await NativeSDK.camera.takePhoto({ quality: 90 });
const { saved } = await NativeSDK.mediaManager.saveImageToGallery(photo.path, {
  quality: 90
});
if (saved) await NativeSDK.toast.show('Photo saved!');

// Record video and save
const video = await NativeSDK.camera.recordVideo();
await NativeSDK.mediaManager.saveVideoToGallery(video.path);

// Download image and save
const dl = await NativeSDK.http.download({
  url: 'https://example.com/image.jpg',
  baseDir: 'temporary'
});
if (dl.saved) {
  await NativeSDK.mediaManager.saveImageToGallery(dl.path);
  await NativeSDK.toast.show('Image saved to gallery!');
}
```
