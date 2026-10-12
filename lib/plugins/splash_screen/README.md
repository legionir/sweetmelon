# Splash Screen Plugin

Control splash screen visibility and auto-hide behavior.

## Plugin Name
`splashScreen`

## Methods

### `show`
| Param | Type | Default |
|-------|------|---------|
| `fadeInDurationMs` | `number` | `200` |

### `hide`
Hides the splash screen.

### `setAutoHide`
| Param | Type | Default |
|-------|------|---------|
| `enabled` | `bool` | `true` |
| `delayMs` | `number` | `3000` |

### `isVisible`
**Returns:** `{ visible: true/false }`

### `getInfo`

**Returns:** `{ name, version, visible, autoHide, autoHideDelayMs }`

## Events
| Event | Data |
|-------|------|
| `splash.shown` | `{ timestamp }` |
| `splash.hidden` | `{ timestamp }` |

## Usage
```javascript
// Hide after app is ready
NativeSDK.waitForReady().then(async () => {
  await loadData();           // load your data first
  await NativeSDK.splashScreen.hide();  // then hide splash
});

// Auto-hide after 3 seconds
await NativeSDK.splashScreen.setAutoHide(true, 3000);

// Manual control
await NativeSDK.splashScreen.show();
setTimeout(() => NativeSDK.splashScreen.hide(), 2000);
```
