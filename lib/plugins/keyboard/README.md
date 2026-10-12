# Keyboard Plugin

Monitor keyboard visibility and height.

## Plugin Name
`keyboard`

## Methods

| Method | Returns |
|--------|---------|
| `getState` | `{ visible, height }` |
| `startWatch` | `{ watching: true }` |
| `stopWatch` | `{ watching: false }` |
| `hide` | `{ hidden: true }` |
| `getInfo` | `{ name, version, watching, visible, height }` |

## Events

### `keyboard.change`
```json
{ "visible": true, "height": 280.5, "timestamp": "..." }
```

## Usage
```javascript
await NativeSDK.keyboard.startWatch();
NativeSDK.on('keyboard.change', (data) => {
  document.body.style.paddingBottom = data.visible ? data.height + 'px' : '0';
});
```
