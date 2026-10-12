# File Opener Plugin

Open files with appropriate system apps.

## Plugin Name
`fileOpener`

## Methods

### `open`
| Param | Type | Required |
|-------|------|----------|
| `path` | `string` | ✅ |
| `mimeType` | `string` | — (auto-detect) |

### `canOpen`
Check if file can be opened.
| Param | Type | Required |
|-------|------|----------|
| `path` | `string` | ✅ |

### `getMimeType`
Get MIME type from file path.
| Param | Type | Required |
|-------|------|----------|
| `path` | `string` | ✅ |

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Open PDF
await NativeSDK.fileOpener.open('/storage/docs/report.pdf');

// Open image
await NativeSDK.fileOpener.open('/storage/photo.jpg', 'image/jpeg');

// Check before opening
const { canOpen } = await NativeSDK.fileOpener.canOpen('/path/to/file.xyz');
if (canOpen) {
  await NativeSDK.fileOpener.open('/path/to/file.xyz');
} else {
  await NativeSDK.toast.show('No app can open this file type');
}

// Get MIME type
const { mimeType } = NativeSDK.fileOpener.getMimeType('/file.mp4');
// "video/mp4"

// Workflow: download then open
const dl = await NativeSDK.http.download({ url: 'https://example.com/doc.pdf' });
if (dl.saved) await NativeSDK.fileOpener.open(dl.path);
```
