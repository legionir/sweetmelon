# Live Updater Plugin

Deploy updates to www assets without Play Store review.

## Plugin Name
`liveUpdater`

## Methods

### `configure`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `serverUrl` | `string` | ✅ | — |
| `apiKey` | `string` | — | — |
| `channel` | `string` | — | `"production"` |
| `currentVersion` | `string` | — | — |

### `checkForUpdate`
**Returns:**
```json
{ "available": true, "currentVersion": "1.0.0", "newVersion": "1.1.0", "size": 524288 }
```

### `downloadUpdate`
Downloads bundle with progress events.

### `applyUpdate`
Apply downloaded bundle. Requires reload.

**Returns:**
```json
{ "applied": true, "previousVersion": "1.0.0", "newVersion": "1.1.0", "requiresReload": true }
```

### `checkAndApply`
One-step: check + download + apply.

### `rollback`
Revert to previous version.

### `getCurrentVersion` / `getAvailableUpdate` / `getStatus`
### `getUpdateHistory` / `reset`
### `setChannel` — `channel` (string ✅, e.g. beta)

### `getInfo`

**Returns:** `{ name, version, currentVersion, status, configured, channel }`

## Events
| Event | Data |
|-------|------|
| `update.available` | `{ version, size, currentVersion }` |
| `update.downloadProgress` | `{ percent, receivedBytes, totalBytes }` |
| `update.downloaded` | `{ version, size }` |
| `update.applied` | `{ previousVersion, newVersion, requiresReload }` |
| `update.rolledBack` | `{ version, requiresReload }` |
| `update.autoRolledBack` | `{ reason, failCount }` |

## Server API Required

```
GET /api/updates/check
Headers:
  X-Current-Version: 1.0.0
  X-Channel: production
  X-Platform: android

Response:
{
  "updateAvailable": true,
  "latestVersion": "1.1.0",
  "bundle": {
    "version": "1.1.0",
    "url": "https://cdn.myapp.com/bundles/1.1.0.zip",
    "checksum": "sha256...",
    "size": 524288
  }
}
```

## Bundle Format
ZIP file containing:
```
1.1.0.zip
├── index.html    ← required
├── css/
├── js/
└── assets/
```

## Usage

### Basic (manual update)
```javascript
await NativeSDK.liveUpdater.configure({
  serverUrl: 'https://updates.myapp.com',
  channel: 'production'
});

const check = await NativeSDK.liveUpdater.checkForUpdate();
if (check.available) {
  
  NativeSDK.on('update.downloadProgress', (data) => {
    progressBar.style.width = data.percent + '%';
  });
  
  await NativeSDK.liveUpdater.downloadUpdate();
  await NativeSDK.liveUpdater.applyUpdate();
  location.reload();
}
```

### Silent background update
```javascript
// Check on startup silently
NativeSDK.waitForReady().then(async () => {
  await NativeSDK.liveUpdater.configure({
    serverUrl: 'https://updates.myapp.com'
  });
  
  const result = await NativeSDK.liveUpdater.checkAndApply();
  if (result.updated) {
    await NativeSDK.toast.show('App updated to v' + result.newVersion);
    setTimeout(() => location.reload(), 2000);
  }
});
```

### Channel management
```javascript
// Beta testers
await NativeSDK.liveUpdater.setChannel('beta');

// Production
await NativeSDK.liveUpdater.setChannel('production');

// Rollback if issues
NativeSDK.on('update.autoRolledBack', async (data) => {
  console.error('Auto-rollback:', data.reason);
  await NativeSDK.firebaseCrashlytics.recordError('Update auto-rolled back', 'UpdateError');
  location.reload();
});
```

## Notes
- Rolled back automatically after 3 consecutive load failures
- Bundle must contain `index.html` in root
- No size limit (but recommend < 10MB for good UX)
- Supports channels: `production`, `staging`, `beta`
