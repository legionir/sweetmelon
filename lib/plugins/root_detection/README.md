# Root Detection Plugin

Detect rooted/jailbroken devices for security.

## Plugin Name
`rootDetection`

## Methods

### `isRooted`
**Returns:**
```json
{
  "isRooted": false,
  "platform": "android",
  "riskLevel": "safe",
  "checks": {
    "suBinary": false,
    "rootApps": false,
    "testKeys": false,
    "magisk": false,
    "busybox": false
  }
}
```

**riskLevel:** `"safe"`, `"low"`, `"medium"`, `"high"`

### `getSecurityInfo`
Returns `isRooted` + `isEmulator`, `isDebugMode`, `adbEnabled`.

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Block on rooted devices (banking/medical)
const { isRooted, riskLevel } = await NativeSDK.rootDetection.isRooted();

if (isRooted) {
  await NativeSDK.dialog.alert({
    title: 'Security Warning',
    message: 'This app cannot run on rooted devices.'
  });
  await NativeSDK.backButton.exitApp();
  return;
}

// Just warn
if (riskLevel === 'medium' || riskLevel === 'high') {
  await NativeSDK.toast.show('⚠️ Running on modified device');
}

// Full security check
const security = await NativeSDK.rootDetection.getSecurityInfo();
await NativeSDK.firebaseCrashlytics.setCustomKeys({
  isRooted: security.isRooted,
  isEmulator: security.isEmulator,
  riskLevel: security.riskLevel
});
```
