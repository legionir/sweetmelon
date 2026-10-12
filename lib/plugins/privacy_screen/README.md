# Privacy Screen Plugin

Prevent screenshots and hide content in app switcher.

## Plugin Name
`privacyScreen`

## Methods

| Method | Returns |
|--------|---------|
| `enable` | `{ enabled: true }` |
| `disable` | `{ enabled: false }` |
| `isEnabled` | `{ enabled: bool }` |
| `getInfo` | `{ name, version, enabled, platform }` |

## Use Cases
- Banking/finance apps
- Medical records
- Password managers
- Private messaging

## Usage
```javascript
// Enable on sensitive screens
router.events.subscribe(event => {
  if (event.url.includes('/account') || event.url.includes('/payment')) {
    NativeSDK.privacyScreen.enable();
  } else {
    NativeSDK.privacyScreen.disable();
  }
});

// Or globally for entire app
NativeSDK.waitForReady().then(() => {
  NativeSDK.privacyScreen.enable();
});
```
