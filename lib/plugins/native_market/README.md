# Native Market Plugin

Link to app store pages.

## Plugin Name
`nativeMarket`

## Methods

### `openStore`
Open this app's Play Store page.
| Param | Type |
|-------|------|
| `packageName` | `string` (optional, defaults to this app) |

### `openDeveloperPage`
| Param | Type | Required |
|-------|------|----------|
| `developerId` | `string` | ✅ |

### `openOtherApp`
Open another app's store page.
| Param | Type | Required |
|-------|------|----------|
| `packageName` | `string` | ✅ |

### `getStoreUrl` — optional `packageName` (defaults to this app)
Get Play Store URL without opening.

### `getInfo`

**Returns:** `{ name, version, packageName }`

## Usage
```javascript
// Rate this app
await NativeSDK.nativeMarket.openStore();

// Open other app
await NativeSDK.nativeMarket.openOtherApp('com.whatsapp');

// Developer page
await NativeSDK.nativeMarket.openDeveloperPage('YourCompanyName');

// Get URL for sharing
const { playStore } = NativeSDK.nativeMarket.getStoreUrl();
await NativeSDK.share.shareText('Download our app: ' + playStore);
```
