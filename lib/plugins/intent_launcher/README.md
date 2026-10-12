# Intent Launcher Plugin

Launch Android intents and system settings.

## Plugin Name
`intentLauncher`

## Methods

### `launch`
| Param | Type | Required |
|-------|------|----------|
| `intent` | `string` | ✅ |

**Known Intents (25+):**
`settings`, `wifi`, `bluetooth`, `location`, `notification`, `battery`, `display`, `sound`, `security`, `date`, `apps`, `developer`, `accessibility`, `storage`, `about`, `vpn`, `data_roaming`, `language`, `keyboard`, `hotspot`, `mobile_data`, `nfc`, `airplane`, `default_apps`, `privacy`

### `launchUrl`
| Param | Type | Default |
|-------|------|---------|
| `url` | `string` | ✅ |
| `mode` | `string` | `"external"` |

### `isAppInstalled`
| Param | Type | Required |
|-------|------|----------|
| `packageName` | `string` | ✅ |

### `getInfo`

**Returns:** `{ name, version, knownIntents }` — `knownIntents` lists every intent name accepted by `launch`.

## Usage
```javascript
// Open system settings
await NativeSDK.intentLauncher.launch('wifi');
await NativeSDK.intentLauncher.launch('developer');

// Check if app installed
const { installed } = await NativeSDK.intentLauncher.isAppInstalled('com.whatsapp');
if (installed) {
  await NativeSDK.intentLauncher.launchUrl('whatsapp://send?phone=989123456789');
} else {
  await NativeSDK.intentLauncher.isAppInstalled('com.android.vending')
    ? NativeSDK.nativeMarket.openOtherApp('com.whatsapp')
    : null;
}

// List all known intents
const { knownIntents } = await NativeSDK.intentLauncher.getInfo();
console.log('Available:', knownIntents.length, 'intents');
```
