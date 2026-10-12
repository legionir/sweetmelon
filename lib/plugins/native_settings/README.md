# Native Settings Plugin

Open Android system settings screens.

## Plugin Name
`nativeSettings`

## Methods

### `open`
| Param | Type | Required |
|-------|------|----------|
| `setting` | `string` | ✅ |

### Shortcut Methods
`openApp`, `openWifi`, `openBluetooth`, `openLocation`, `openNotification`, `openBattery`, `openDisplay`, `openSound`, `openSecurity`, `openDate`, `openAccessibility`, `openStorage`, `openDeveloper`, `openAbout`

### `getAvailableSettings`
Returns all supported setting names.

### `getInfo`

**Returns:** `{ name, version, platform, availableSettings }`

## Available Settings
`app`, `wifi`, `bluetooth`, `location`, `notification`, `battery`, `display`, `sound`, `security`, `date`, `accessibility`, `storage`, `developer`, `about`, `nfc`, `airplane`, `apn`, `data_usage`, `vpn`, `input_method`, `locale`, `privacy`, `biometric`, `default_apps`

## Usage
```javascript
// Guide user to enable location
const perm = await NativeSDK.permission.check('location');
if (perm.permanentlyDenied) {
  await NativeSDK.dialog.alert({
    message: 'Please enable location in settings'
  });
  await NativeSDK.nativeSettings.openLocation();
}

// Open notification settings
await NativeSDK.nativeSettings.openNotification();

// Open app-specific settings
await NativeSDK.nativeSettings.openApp();

// Generic open
await NativeSDK.nativeSettings.open('wifi');
await NativeSDK.nativeSettings.open('biometric');
```
