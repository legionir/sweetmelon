# Haptic Plugin

Vibration and haptic feedback.

## Plugin Name
`haptic`

## Methods

| Method | Description |
|--------|-------------|
| `lightImpact` | Light haptic tap |
| `mediumImpact` | Medium haptic tap |
| `heavyImpact` | Heavy haptic tap |
| `selectionClick` | Selection tick |
| `vibrate` | Standard vibration |
| `getInfo` | Returns plugin info: `{ name, version, supportedTypes }` |

## Usage
```javascript
await NativeSDK.haptic.lightImpact();    // subtle feedback
await NativeSDK.haptic.heavyImpact();    // strong feedback
```
