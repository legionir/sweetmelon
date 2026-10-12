# Firebase Crashlytics Plugin

Crash reporting and diagnostics.

## Plugin Name
`firebaseCrashlytics`

## Methods

### `recordError`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `message` | `string` | ✅ | — |
| `type` | `string` | — | `"Error"` |
| `fatal` | `bool` | — | `false` |
| `keys` | `object` | — | — |

### `log` — Add log message to crash report; `message` required
### `setUserId` — `id` (string ✅)
### `setCustomKey` — `key` + `value` (both required)
### `setCustomKeys` — `keys` (object ✅)
### `sendUnsentReports` / `deleteUnsentReports`
### `checkForUnsentReports`
### `setCrashlyticsCollectionEnabled` — `enabled` (bool ✅)
### `crash` — force a native crash (debug builds only; returns `{ crashed: false, reason: "only_in_debug" }` in release)

### `getInfo`

**Returns:** `{ name, version, initialized, isCrashlyticsCollectionEnabled }`

## Usage
```javascript
// Global error handler
window.addEventListener('error', (event) => {
  NativeSDK.firebaseCrashlytics.recordError(event.message, 'JSError', {
    fatal: false,
    keys: {
      filename: event.filename,
      lineno: event.lineno,
      colno: event.colno
    }
  });
});

// User context
await NativeSDK.firebaseCrashlytics.setUserId(currentUser.id);
await NativeSDK.firebaseCrashlytics.setCustomKeys({
  plan: currentUser.plan,
  version: appVersion,
  screen: currentRoute
});

// Breadcrumbs
await NativeSDK.firebaseCrashlytics.log('User opened checkout');
await NativeSDK.firebaseCrashlytics.log('Payment processing started');

// Try/catch with reporting
try {
  await processPayment();
} catch (error) {
  await NativeSDK.firebaseCrashlytics.recordError(error.message, 'PaymentError');
  await NativeSDK.dialog.alert({ message: 'Payment failed. Please try again.' });
}
```
