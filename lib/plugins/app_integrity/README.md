# App Integrity Plugin

Verify app installation authenticity.

## Plugin Name
`appIntegrity`

## Methods

### `checkIntegrity`
**Returns:**
```json
{
  "verdict": "trusted",
  "genuine": true,
  "playStore": true,
  "install": { "genuine": true },
  "source": { "source": "com.android.vending" }
}
```

**verdict:** `"trusted"` | `"genuine"` | `"untrusted"`

### `isGenuineInstall` / `getInstallSource` / `getSigningInfo`

### `getInfo`

**Returns:** `{ name, version, platform, playIntegrityReady }`

## Usage
```javascript
const integrity = await NativeSDK.appIntegrity.checkIntegrity();

switch (integrity.verdict) {
  case 'trusted':
    // Play Store install, proceed normally
    break;
  case 'genuine':
    // Signed correctly but not from Play Store (sideloaded)
    await NativeSDK.toast.show('Please install from Play Store');
    break;
  case 'untrusted':
    // Modified or unknown installation
    await NativeSDK.dialog.alert({
      title: 'Security',
      message: 'Please download from the official Play Store.'
    });
    await NativeSDK.nativeMarket.openStore();
    break;
}
```
