# File System Plugin

Sandboxed file system access with path traversal protection.

## Plugin Name
`fileSystem`

## Base Directories
| Name | Description |
|------|-------------|
| `documents` | App documents (default) |
| `cache` | App cache |
| `support` | App support |
| `temporary` | Temporary files |

## Methods

### `getDirectories`
**Returns:** paths for all base directories

### `writeFile`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `path` | `string` | ✅ | — |
| `content` | `string` | ✅ | — |
| `baseDir` | `string` | — | `documents` |
| `encoding` | `string` | — | `utf8` |
| `append` | `bool` | — | `false` |

### `readFile`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `path` | `string` | ✅ | — |
| `baseDir` | `string` | — | `documents` |
| `encoding` | `string` | — | `utf8` |

### `deleteFile`, `fileExists`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `path` | `string` | ✅ | — |
| `baseDir` | `string` | — | `documents` |

### `stat`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `path` | `string` | ✅ | — |
| `baseDir` | `string` | — | `documents` |
| `type` | `string` | — | `"file"` (`"directory"` supported) |

### `listFiles`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `path` | `string` | — | `""` (root) |
| `baseDir` | `string` | — | `documents` |
| `recursive` | `bool` | — | `false` |

### `browse`
Read-only listing of the device's **shared storage** (outside the app sandbox),
one folder level per call. Without `path` it returns the storage roots
(internal storage, SD cards). Only paths under those roots are served, symlinks
are resolved before the check, hidden entries are skipped and nothing can be
written or deleted. Ask for the `audio` / `storage` permission first.
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `path` | `string` | — | `""` (storage roots) |
| `extensions` | `string[]` | — | all files (folders are always listed) |

**Returns:** `{ path, parent, items: [{ name, path, type, size, extension, modified }] }`
(`parent` is `""` for a root, `null` at the list of roots).

### `createDirectory`, `deleteDirectory`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `path` | `string` | ✅ | — |
| `baseDir` | `string` | — | `documents` |
| `recursive` | `bool` | — | `false` |

### `getInfo`

**Returns:** `{ name, version, supportedBaseDirs, encodings }`

## Usage
```javascript
await NativeSDK.fileSystem.writeFile('logs/app.log', 'Hello World');
const { content } = await NativeSDK.fileSystem.readFile('logs/app.log');
const { items } = await NativeSDK.fileSystem.listFiles('logs', { recursive: true });
```

## Security
- Path traversal (`..`) is blocked
- All paths are sandboxed to base directories
