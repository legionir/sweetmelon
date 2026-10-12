# Background Geolocation Plugin

Track device location even when app is in background.

## Plugin Name
`backgroundGeolocation`

## Methods

### `startTracking`
| Param | Type | Default |
|-------|------|---------|
| `accuracy` | `string` | `"high"` |
| `distanceFilter` | `number` (meters) | `10` |
| `intervalMs` | `number` | — |
| `maxHistory` | `number` | `500` |

### `stopTracking`
### `getLastPosition`
### `getHistory`
| Param | Type |
|-------|------|
| `limit` | `number` |
| `sinceMs` | `number` (timestamp) |

### `clearHistory`
### `isTracking`

### `getInfo`

**Returns:** `{ name, version, tracking, updateCount, historyCount, lastPosition }`

## Events
| Event | Data |
|-------|------|
| `bgGeo.position` | `{ latitude, longitude, accuracy, speed, heading, timestamp }` |
| `bgGeo.error` | `{ message, timestamp }` |

## Usage
```javascript
// Start tracking (requires ForegroundService for background)
await NativeSDK.foregroundService.start({
  title: 'Tracking your journey'
});

await NativeSDK.backgroundGeolocation.startTracking({
  accuracy: 'high',
  distanceFilter: 20  // update every 20m
});

NativeSDK.on('bgGeo.position', async (pos) => {
  // Send to server
  await NativeSDK.http.post('https://api.myapp.com/location', pos);
  
  // Update map
  updateMapMarker(pos.latitude, pos.longitude);
});

// Get history for route display
const { positions } = await NativeSDK.backgroundGeolocation.getHistory({
  limit: 100
});
drawRoute(positions);

// Stop tracking
await NativeSDK.backgroundGeolocation.stopTracking();
await NativeSDK.foregroundService.stop();
```
