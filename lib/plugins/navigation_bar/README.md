# Navigation Bar Plugin

Control Android navigation bar appearance.

## Plugin Name
`navigationBar`

## Methods

### `setColor`
| Param | Type | Required |
|-------|------|----------|
| `color` | `string` (#RRGGBB) | ✅ |
| `darkIcons` | `bool` | — |

### `setStyle`
| Param | Type | Values |
|-------|------|--------|
| `style` | `string` | `"light"`, `"dark"`, `"default"` |

### `show` / `hide` / `setTransparent`

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Match app theme
await NativeSDK.navigationBar.setColor('#1A1A2E', false); // dark icons off

// Light theme
await NativeSDK.navigationBar.setStyle('dark'); // dark icons on white bg

// Transparent for fullscreen
await NativeSDK.navigationBar.setTransparent();

// Video fullscreen
await NativeSDK.statusBar.hide();
await NativeSDK.navigationBar.hide();

// Restore
await NativeSDK.statusBar.show();
await NativeSDK.navigationBar.show();
```
