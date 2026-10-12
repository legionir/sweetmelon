# File Picker Plugin

Pick files, images, videos from device storage.

## Plugin Name
`filePicker`

## Methods

### `pickFiles`
| Param | Type | Default |
|-------|------|---------|
| `multiple` | `bool` | `false` |
| `type` | `string` | `"any"` |
| `allowedExtensions` | `string[]` | — |
| `withData` | `bool` (also return file bytes) | `false` |

**type:** `any`, `image`, `video`, `audio`, `media`

### `pickImages` / `pickVideos` / `pickMedia` — shortcuts for pickFiles with type preset; same params: `multiple`, `type`, `allowedExtensions`, `withData`

### `pickDirectory`
Pick a directory path.

**Returns:**
```json
{
  "picked": true,
  "files": [
    { "name": "doc.pdf", "path": "/...", "size": 12345, "extension": "pdf" }
  ],
  "count": 1
}
```

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Pick any file
const { files } = await NativeSDK.filePicker.pickFiles();

// Pick images only
const { files } = await NativeSDK.filePicker.pickImages({ multiple: true });

// Pick specific extensions
const { files } = await NativeSDK.filePicker.pickFiles({
  allowedExtensions: ['pdf', 'doc', 'docx', 'xlsx'],
  multiple: true
});

// Upload picked file
if (files.length > 0) {
  const file = files[0];
  const formData = new FormData();
  formData.append('file', { uri: file.path, name: file.name });
  await fetch('/upload', { method: 'POST', body: formData });
}

// Pick directory
const { path } = await NativeSDK.filePicker.pickDirectory();
console.log('Selected dir:', path);
```
