# Share Plugin

Native share sheet for text and files.

## Plugin Name
`share`

## Methods

### `shareText`
| Param | Type | Required |
|-------|------|----------|
| `text` | `string` | ✅ |
| `subject` | `string` | — |

### `shareFiles`
| Param | Type | Required |
|-------|------|----------|
| `paths` | `string[]` | ✅ |
| `text` | `string` | — |
| `subject` | `string` | — |

## Usage
```javascript
await NativeSDK.share.shareText('Check out this app!', 'Sweetmelon');

// Share a file (must use absolute path from fileSystem)
const dirs = await NativeSDK.fileSystem.getDirectories();
await NativeSDK.share.shareFiles(
  [dirs.documents + '/reports/report.pdf'],
  'Monthly report attached'
);
```
