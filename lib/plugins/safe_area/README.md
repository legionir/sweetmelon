# Safe Area Plugin

Get device safe area insets for notches and system bars.

## Plugin Name
`safeArea`

## Methods

### `getInsets`
**Returns:**
```json
{
  "padding": { "top": 44, "bottom": 34, "left": 0, "right": 0 },
  "viewInsets": { "top": 0, "bottom": 0, "left": 0, "right": 0 },
  "viewPadding": { "top": 44, "bottom": 34, "left": 0, "right": 0 }
}
```

### `getScreenInfo`
**Returns:**
```json
{
  "width": 390,
  "height": 844,
  "physicalWidth": 1170,
  "physicalHeight": 2532,
  "devicePixelRatio": 3.0,
  "orientation": "portrait",
  "textScaleFactor": 1.0
}
```

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Apply safe area padding to content
const { padding } = await NativeSDK.safeArea.getInsets();
document.body.style.paddingTop = padding.top + 'px';
document.body.style.paddingBottom = padding.bottom + 'px';

// CSS variables approach
const insets = await NativeSDK.safeArea.getInsets();
document.documentElement.style.setProperty('--safe-top', insets.padding.top + 'px');
document.documentElement.style.setProperty('--safe-bottom', insets.padding.bottom + 'px');

// Adjust layout on keyboard show
NativeSDK.on('keyboard.change', async (kb) => {
  const { viewInsets } = await NativeSDK.safeArea.getInsets();
  document.getElementById('main').style.marginBottom = kb.visible 
    ? kb.height + 'px' 
    : insets.padding.bottom + 'px';
});
```
