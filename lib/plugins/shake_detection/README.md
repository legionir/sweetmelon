# Shake Detection Plugin

Detect device shake gesture.

## Plugin Name
`shakeDetection`

## Methods

### `startListening`
| Param | Type | Default |
|-------|------|---------|
| `threshold` | `number` | `15.0` |
| `cooldownMs` | `number` | `1000` |

### `configure`
| Param | Type |
|-------|------|
| `threshold` | `number` |
| `cooldownMs` | `number` |

### `stopListening` / `getShakeCount` / `resetCount` / `isListening`

### `getInfo`

**Returns:** `{ name, version, listening, threshold, cooldownMs, shakeCount }`

## Events
| Event | Data |
|-------|------|
| `shake.detected` | `{ magnitude, count, timestamp }` |

## Usage
```javascript
// Shake to undo
await NativeSDK.shakeDetection.startListening({ threshold: 12, cooldownMs: 1500 });

NativeSDK.on('shake.detected', async () => {
  await NativeSDK.haptic.mediumImpact();
  
  const { confirmed } = await NativeSDK.dialog.confirm({
    message: 'Undo last action?',
    okButtonTitle: 'Undo'
  });
  if (confirmed) undoLastAction();
});

// Shake to refresh
NativeSDK.on('shake.detected', () => {
  refreshData();
  NativeSDK.haptic.lightImpact();
  NativeSDK.toast.show('Refreshing...');
});

// Stop when not needed
await NativeSDK.shakeDetection.stopListening();
```
