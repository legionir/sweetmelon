# Biometrics Plugin

Fingerprint and face recognition authentication.

## Plugin Name
`biometrics`

## Methods

### `isAvailable`
**Returns:** `{ available: true, canCheckBiometrics: true, isDeviceSupported: true }`

### `getAvailableBiometrics`
**Returns:** `{ hasFingerprint: true, hasFace: false, biometrics: ["fingerprint", "strong"] }`

### `authenticate`
| Param | Type | Default |
|-------|------|---------|
| `reason` | `string` | `"Please authenticate"` |
| `biometricOnly` | `bool` | `false` |
| `stickyAuth` | `bool` | `true` |
| `sensitiveTransaction` | `bool` | `true` |

**Returns:**
```json
{ "authenticated": true, "method": "biometric" }
```
Or on failure:
```json
{ "authenticated": false, "errorCode": "not_enrolled", "errorMessage": "..." }
```

### `getInfo`

**Returns:** `{ name, version, platform }`

## Usage
```javascript
const { available } = await NativeSDK.biometrics.isAvailable();
if (available) {
  const { authenticated } = await NativeSDK.biometrics.authenticate({
    reason: 'Verify to access wallet'
  });
  if (authenticated) {
    showWallet();
  }
}
```
