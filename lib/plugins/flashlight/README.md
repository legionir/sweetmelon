# Flashlight Plugin

Control device camera flashlight/torch.

## Plugin Name
`flashlight`

## Methods

| Method | Returns |
|--------|---------|
| `enable` | `{ enabled: true }` |
| `disable` | `{ enabled: false }` |
| `toggle` | current state |
| `isAvailable` | `{ available: bool }` |
| `isEnabled` | `{ enabled: bool }` |
| `getInfo` | `{ name, version, enabled }` |

## Usage
```javascript
// Check support
const { available } = await NativeSDK.flashlight.isAvailable();
if (!available) {
  await NativeSDK.toast.show('No flashlight available');
  return;
}

// Toggle button
document.getElementById('torchBtn').onclick = async () => {
  const { enabled } = await NativeSDK.flashlight.toggle();
  torchBtn.textContent = enabled ? '🔦 ON' : '🔦 OFF';
};

// Auto off when app goes to background
NativeSDK.on('app.lifecycle.change', async (state) => {
  if (state.state === 'paused') {
    await NativeSDK.flashlight.disable();
  }
});
```
