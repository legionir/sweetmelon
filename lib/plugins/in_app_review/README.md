# In-App Review Plugin

Prompt users for app store ratings without leaving the app.

## Plugin Name
`inAppReview`

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `isAvailable` | — | `{ available: bool }` |
| `requestReview` | — | `{ requested: bool }` |
| `openStoreListing` | `appStoreId` (string, iOS, optional) | `{ opened: bool }` |
| `getInfo` | — | `{ name, version }` |

## Important Notes
- Google limits how often the review dialog can be shown
- Don't call after a button press — trigger naturally after positive actions
- No guarantee the dialog will appear every time

## Usage
```javascript
// After completing a key action
async function onOrderCompleted() {
  const { available } = await NativeSDK.inAppReview.isAvailable();
  if (!available) return;

  // Check if enough time has passed (track in storage)
  const lastReview = await NativeSDK.storage.get('last_review_request');
  const daysSince = lastReview 
    ? (Date.now() - lastReview) / 86400000 
    : Infinity;

  if (daysSince > 30) {  // once per 30 days max
    await NativeSDK.inAppReview.requestReview();
    await NativeSDK.storage.set('last_review_request', Date.now());
  }
}

// Explicit store link (settings page)
await NativeSDK.inAppReview.openStoreListing();
```
