# Screenshot Plugin

Capture screenshots of the current view.

## Plugin Name
`screenshot`

## Methods

### `capture`
| Param | Type | Default |
|-------|------|---------|
| `format` | `string` | `"png"` |
| `fileName` | `string` | auto |
| `baseDir` | `string` | `"temporary"` |

**format:** `"png"` or `"jpg"`

**Returns:**
```json
{
  "captured": true,
  "path": "/tmp/screenshots/screenshot_1234.png",
  "fileName": "screenshot_1234.png",
  "size": 245678,
  "width": 1080,
  "height": 2400
}
```

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Simple screenshot
const shot = await NativeSDK.screenshot.capture();
await NativeSDK.share.shareFiles([shot.path]);

// High quality
const shot = await NativeSDK.screenshot.capture({
  format: 'png',
  quality: 100,
  fileName: 'bug_report'
});

// Bug report workflow
document.getElementById('reportBtn').onclick = async () => {
  const shot = await NativeSDK.screenshot.capture({ format: 'jpg' });
  const form = new FormData();
  form.append('screenshot', shot.path);
  form.append('description', userInput.value);
  await fetch('/api/bug-report', { method: 'POST', body: form });
};
```
