# App Update Plugin

Check for app updates and open store.

## Plugin Name
`appUpdate`

## Methods

### `configure`
| Param | Type | Description |
|-------|------|-------------|
| `updateCheckUrl` | `string` | Your server endpoint |
| `playStoreUrl` | `string` | Play Store URL |

### `getCurrentVersion`
**Returns:**
```json
{ "version": "1.2.0", "buildNumber": "45", "packageName": "com.example.app" }
```

### `checkForUpdate`
| Param | Type |
|-------|------|
| `url` | `string` (override) |

**Server Response Expected:**
```json
{
  "latestVersion": "1.3.0",
  "minVersion": "1.1.0",
  "forceUpdate": false,
  "releaseNotes": "Bug fixes",
  "storeUrl": "https://play.google.com/..."
}
```

**Returns:**
```json
{
  "updateAvailable": true,
  "mustUpdate": false,
  "currentVersion": "1.2.0",
  "latestVersion": "1.3.0",
  "releaseNotes": "Bug fixes"
}
```

### `openStore`
| Param | Type |
|-------|------|
| `url` | `string` (optional) |

### `getLastCheckResult`

### `getInfo`

**Returns:** `{ name, version, currentVersion, buildNumber, configured }`

## Events
| Event | Data |
|-------|------|
| `appUpdate.available` | full check result |

## Usage
```javascript
await NativeSDK.appUpdate.configure({
  updateCheckUrl: 'https://api.myapp.com/version'
});

const update = await NativeSDK.appUpdate.checkForUpdate();

if (update.mustUpdate) {
  await NativeSDK.dialog.alert({
    title: 'Update Required',
    message: 'Please update the app to continue.'
  });
  await NativeSDK.appUpdate.openStore();
} else if (update.updateAvailable) {
  const { confirmed } = await NativeSDK.dialog.confirm({
    title: 'Update Available',
    message: `Version ${update.latestVersion} is available. Update now?`
  });
  if (confirmed) await NativeSDK.appUpdate.openStore();
}
```
