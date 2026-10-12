# Status Bar Plugin

Control Android status bar appearance.

## Plugin Name
`statusBar`

## Methods

| Method | Args |
|--------|------|
| `setStyle` | `style: "light"/"dark"`, `backgroundColor?: "#RRGGBB"` |
| `setColor` | `color: "#RRGGBB"`, `navigationBarColor?: "#RRGGBB"` |
| `show` | — |
| `hide` | — |
| `setFullscreen` | Immersive sticky fullscreen |
| `exitFullscreen` | Exit fullscreen |
| `getInfo` | — (returns `{ name, version, supportedStyles }`) |

## Usage
```javascript
await NativeSDK.statusBar.setStyle('dark', '#FFFFFF');
await NativeSDK.statusBar.setFullscreen();
// ...
await NativeSDK.statusBar.exitFullscreen();
```
