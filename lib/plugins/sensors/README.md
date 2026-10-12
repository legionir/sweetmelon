# Sensors Plugin

Access device motion and orientation sensors.

## Plugin Name
`sensors`

## Methods

| Method | Sensor | Description |
|--------|--------|-------------|
| `startAccelerometer` | Accelerometer | gravity + motion (m/s²) |
| `stopAccelerometer` | — | — |
| `startGyroscope` | Gyroscope | rotation rate (rad/s) |
| `stopGyroscope` | — | — |
| `startMagnetometer` | Magnetometer | magnetic field (μT) |
| `stopMagnetometer` | — | — |
| `startUserAccelerometer` | User Accel | motion without gravity |
| `stopUserAccelerometer` | — | — |
| `stopAll` | — | stop all sensors |
| `getActiveStreams` | — | list active sensors |
| `getInfo` | — | Plugin info: `{ name, version, activeStreams, availableSensors }` |

### `startAccelerometer` / `startGyroscope` / `startMagnetometer` / `startUserAccelerometer`
| Param | Type | Default |
|-------|------|---------|
| `intervalMs` | `number` | `100` |

## Events
| Event | Data |
|-------|------|
| `sensors.accelerometer` | `{ x, y, z, timestamp }` |
| `sensors.gyroscope` | `{ x, y, z, timestamp }` |
| `sensors.magnetometer` | `{ x, y, z, timestamp }` |
| `sensors.userAccelerometer` | `{ x, y, z, timestamp }` |

## Usage
```javascript
// Shake detection (manual)
let lastX = 0, lastY = 0, lastZ = 0;
await NativeSDK.sensors.startAccelerometer({ intervalMs: 50 });
NativeSDK.on('sensors.accelerometer', (data) => {
  const delta = Math.abs(data.x - lastX) + Math.abs(data.y - lastY);
  if (delta > 15) console.log('Shake!');
  lastX = data.x; lastY = data.y; lastZ = data.z;
});

// Compass heading
await NativeSDK.sensors.startMagnetometer({ intervalMs: 200 });
NativeSDK.on('sensors.magnetometer', (data) => {
  const heading = Math.atan2(data.y, data.x) * (180 / Math.PI);
  updateCompass(heading);
});

// Gyroscope for rotation
await NativeSDK.sensors.startGyroscope({ intervalMs: 100 });
NativeSDK.on('sensors.gyroscope', (data) => {
  rotateObject(data.x, data.y, data.z);
});

// Cleanup
await NativeSDK.sensors.stopAll();
```
