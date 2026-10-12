# Accessibility Plugin

Detect and respond to accessibility features.

## Plugin Name
`accessibility`

## Methods

### `isScreenReaderEnabled`
**Returns:** `{ enabled: bool }`

### `announce`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `message` | `string` | ✅ | — |
| `assertiveness` | `string` | — | `"polite"` |

### `getSettings`
**Returns:**
```json
{
  "screenReaderEnabled": false,
  "boldText": false,
  "reduceMotion": false,
  "highContrast": false,
  "invertColors": false,
  "disableAnimations": false
}
```

### `isBoldTextEnabled` / `isReduceMotionEnabled` / `isHighContrastEnabled`

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Adapt UI to accessibility settings
const settings = await NativeSDK.accessibility.getSettings();

if (settings.reduceMotion) {
  document.body.classList.add('no-animations');
}

if (settings.highContrast) {
  document.body.classList.add('high-contrast');
}

// Screen reader announcements
const { enabled } = await NativeSDK.accessibility.isScreenReaderEnabled();
if (enabled) {
  await NativeSDK.accessibility.announce('Page loaded: Home screen');
}

// Route changes
router.events.subscribe(event => {
  NativeSDK.accessibility.announce('Navigated to ' + event.url);
});
```
