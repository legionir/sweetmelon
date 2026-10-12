# Kiosk Mode Plugin

Lock device into single-app kiosk mode.

## Plugin Name
`kioskMode`

## Methods

| Method | Returns |
|--------|---------|
| `enable` | `{ enabled: true }` |
| `disable` | `{ enabled: false }` |
| `isEnabled` | `{ enabled: bool }` |
| `getInfo` | `{ name, version, enabled }` |

## What it does
- Hides status bar (immersive sticky)
- Locks screen orientation to portrait
- Prevents navigation away from app

## Usage
```javascript
// Retail kiosk
await NativeSDK.kioskMode.enable();

// Admin unlock (hidden gesture)
let tapCount = 0;
document.getElementById('logo').onclick = async () => {
  tapCount++;
  if (tapCount >= 5) {
    const { value } = await NativeSDK.dialog.prompt({
      title: 'Admin Access',
      placeholder: 'Enter PIN',
      inputType: 'number'
    });
    if (value === '1234') {
      await NativeSDK.kioskMode.disable();
      tapCount = 0;
    }
  }
};
```
