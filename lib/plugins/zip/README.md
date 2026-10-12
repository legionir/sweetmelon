# Zip Plugin

Create and extract ZIP archives.

## Plugin Name
`zip`

## Methods

### `zip`
| Param | Type | Required |
|-------|------|----------|
| `paths` | `string[]` | ✅ |
| `outputPath` | `string` | — (auto) |

**Returns:**
```json
{
  "zipped": true,
  "outputPath": "/tmp/archive.zip",
  "fileCount": 5,
  "originalSize": 1024000,
  "compressedSize": 256000,
  "compressionRatio": 75
}
```

### `unzip`
| Param | Type | Required |
|-------|------|----------|
| `path` | `string` | ✅ |
| `outputDir` | `string` | — (auto) |

### `listContents`
| Param | Type | Required |
|-------|------|----------|
| `path` | `string` | ✅ |

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Create zip backup
const dirs = await NativeSDK.fileSystem.getDirectories();
const archive = await NativeSDK.zip.zip([
  dirs.documents + '/reports',
  dirs.documents + '/data.json'
], dirs.documents + '/backup.zip');
console.log(`Archive: ${archive.compressionRatio}% compression`);

// Share the zip
await NativeSDK.share.shareFiles([archive.outputPath]);

// Extract update bundle
const dl = await NativeSDK.http.download({ url: 'https://cdn.app.com/update.zip' });
const extracted = await NativeSDK.zip.unzip(dl.path, dirs.documents + '/update');
console.log('Extracted:', extracted.fileCount, 'files');

// List contents without extracting
const { files } = await NativeSDK.zip.listContents('/path/to/archive.zip');
files.forEach(f => console.log(f.name, f.size));
```
