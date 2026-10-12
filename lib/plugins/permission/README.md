# Permission Plugin

Manage native Android/iOS permissions from JavaScript.

## Plugin Name
`permission`

## Methods

### `check`
Check a single permission status.

**Args:**
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `permission` | `string` | ✅ | Permission name |

**Returns:**
```json
{
  "permission": "camera",
  "status": "granted",
  "granted": true,
  "permanentlyDenied": false
}
```

### `request`
Request a single permission.

**Args:**
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `permission` | `string` | ✅ | Permission name |

**Returns:** Same as `check`.

### `checkMany`
Check multiple permissions at once.

**Args:**
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `permissions` | `string[]` | ✅ | List of permission names |

**Returns:**
```json
{
  "results": {
    "camera": { "status": "granted", "granted": true },
    "location": { "status": "denied", "granted": false }
  }
}
```

### `requestMany`
Request multiple permissions.

**Args:**
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `permissions` | `string[]` | ✅ | Permission names |

**Returns:** Same as `checkMany`.

### `openSettings`
Open app settings page.

**Returns:** `{ "opened": true }`

### `getKnownPermissions`
List all supported permission names.

**Returns:** `{ "permissions": ["camera", "storage", "location", ...] }`

## Known Permission Names
`camera`, `storage`, `manageExternalStorage`, `location`, `locationAlways`,
`microphone`, `photos`, `notification`, `contacts`, `bluetooth`

## Usage
```javascript
// Check
const result = await NativeSDK.permission.check('camera');
if (!result.granted) {
  await NativeSDK.permission.request('camera');
}

// Check multiple
const all = await NativeSDK.permission.checkMany(['camera', 'location', 'microphone']);

// Open settings if permanently denied
if (result.permanentlyDenied) {
  await NativeSDK.permission.openSettings();
}
```
