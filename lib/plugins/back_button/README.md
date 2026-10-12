# Back Button Plugin

Intercept Android back button for SPA navigation.

## Plugin Name
`backButton`

## Methods

| Method | Args | Description |
|--------|------|-------------|
| `enableIntercept` | — | Start intercepting back button |
| `disableIntercept` | — | Stop intercepting |
| `getState` | — | Get current intercept state |
| `exitApp` | — | Close the app |
| `setExitOnBack` | `enabled` (bool, default false) | Exit app when back is pressed |
| `minimizeApp` | — | Minimize to background |

## Events

### `backButton.pressed`
Fired when back button is pressed (only when intercept is enabled).

## Usage
```javascript
await NativeSDK.backButton.enableIntercept();

NativeSDK.on('backButton.pressed', () => {
  if (canGoBack()) {
    window.history.back();
  } else {
    if (confirm('Exit app?')) {
      NativeSDK.backButton.exitApp();
    }
  }
});
```
