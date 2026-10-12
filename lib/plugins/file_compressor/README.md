# File Compressor Plugin

Compress images before upload or storage.

## Plugin Name
`fileCompressor`

## Methods

### `compressImage`
| Param | Type | Default |
|-------|------|---------|
| `path` | `string` | ✅ |
| `quality` | `number` 1-100 | `80` |
| `maxWidth` | `number` | `1920` |
| `maxHeight` | `number` | `1080` |
| `format` | `string` | `"jpeg"` |
| `keepExif` | `bool` | `false` |

**format:** `"jpeg"`, `"png"`, `"webp"`

### `compressToWebP` — same as compressImage: `path`, `quality`, `maxWidth`, `maxHeight`, `keepExif` (`format` is ignored — always webp)

**Returns:**
```json
{
  "compressed": true,
  "inputPath": "/original.jpg",
  "outputPath": "/compressed.jpg",
  "originalSize": 2048000,
  "compressedSize": 512000,
  "savings": 75,
  "format": "jpeg"
}
```

### `getInfo`

**Returns:** `{ name, version, supportedFormats }`

## Usage
```javascript
// Before upload
const photo = await NativeSDK.camera.takePhoto({ quality: 100 });
const compressed = await NativeSDK.fileCompressor.compressImage(photo.path, {
  quality: 70,
  maxWidth: 1280,
  format: 'webp'
});
console.log(`Saved ${compressed.savings}%`);  // "Saved 75%"
uploadFile(compressed.outputPath);

// Profile picture - small size
const avatar = await NativeSDK.filePicker.pickImages();
const small = await NativeSDK.fileCompressor.compressImage(avatar.files[0].path, {
  quality: 85,
  maxWidth: 256,
  maxHeight: 256
});
uploadAvatar(small.outputPath);
```
