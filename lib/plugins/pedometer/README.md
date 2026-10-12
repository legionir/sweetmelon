# Pedometer Plugin

Track steps using device pedometer sensor.

## Plugin Name
`pedometer`

## Methods

| Method | Returns |
|--------|---------|
| `startTracking` | `{ started: bool }` |
| `stopTracking` | `{ stopped: bool, lastSteps: number }` |
| `getStepCount` | `{ steps: number }` |
| `getStatus` | `{ status: "walking"/"stopped" }` |
| `isTracking` | `{ tracking: bool }` |
| `getInfo` | `{ name, version, tracking, lastStepCount, lastStatus }` |

## Events
| Event | Data |
|-------|------|
| `pedometer.step` | `{ steps, timestamp }` |
| `pedometer.status` | `{ status: "walking"/"stopped", timestamp }` |
| `pedometer.error` | `{ message }` |

## Usage
```javascript
// Daily step counter
await NativeSDK.pedometer.startTracking();

NativeSDK.on('pedometer.step', (data) => {
  document.getElementById('steps').textContent = data.steps.toLocaleString();
  
  const goal = 10000;
  const progress = Math.min(100, (data.steps / goal) * 100);
  progressRing.style.strokeDashoffset = 100 - progress;
});

NativeSDK.on('pedometer.status', (data) => {
  statusLabel.textContent = data.status === 'walking' ? '🚶 Walking' : '⏸ Stopped';
});

// Save daily count
NativeSDK.on('app.lifecycle.change', async (state) => {
  if (state.state === 'paused') {
    const { steps } = await NativeSDK.pedometer.getStepCount();
    await NativeSDK.storage.set('steps_today', steps);
  }
});
```
