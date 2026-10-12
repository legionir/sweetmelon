# Cache Control Plugin

Control WebView and app cache.

## Plugin Name
`cacheControl`

## Methods

### `clearWebViewCache`
Clear WebView HTTP cache and local storage.

### `clearAppCache`
Delete files in app cache directory.

### `getCacheSize`
**Returns:**
```json
{
  "cache": { "bytes": 1234567, "formatted": "1.2MB", "files": 45 },
  "temp": { "bytes": 234567, "formatted": "234KB", "files": 12 },
  "total": { "bytes": 1469134, "formatted": "1.4MB", "files": 57 }
}
```

### `clearAll`
Clear WebView cache + app cache + temp files.

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Check cache size
const { total } = await NativeSDK.cacheControl.getCacheSize();
console.log('Cache:', total.formatted);  // "1.4MB"

// Clear before forced update
await NativeSDK.cacheControl.clearWebViewCache();
location.reload();

// Full cleanup
const result = await NativeSDK.cacheControl.clearAll();
console.log('Freed:', result.appCache.bytesFreedFormatted);

// Settings page - clear cache button
document.getElementById('clearCacheBtn').onclick = async () => {
  await NativeSDK.cacheControl.clearAll();
  await NativeSDK.toast.show('Cache cleared!');
};
```
