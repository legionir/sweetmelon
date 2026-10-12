# Foreground Service Plugin

Run persistent Android foreground services.

## Plugin Name
`foregroundService`

## Methods

### `start`
| Param | Type | Default |
|-------|------|---------|
| `title` | `string` | `"App is running"` |
| `body` | `string` | `"Tap to return"` |
| `channelId` | `string` | `"foreground_service"` |
| `channelName` | `string` | `"Foreground Service"` |

### `stop`
### `update`
| Param | Type |
|-------|------|
| `title` | `string` |
| `body` | `string` |

### `isRunning`

### `getInfo`

**Returns:** `{ name, version, running, title, body }`

## Events
| Event | Data |
|-------|------|
| `foregroundService.started` | `{ title, timestamp }` |
| `foregroundService.stopped` | `{ timestamp }` |

## Use Cases
- Background location tracking
- Music/audio playback
- File upload/download
- Real-time sync

## Usage
```javascript
// Location tracking service
await NativeSDK.foregroundService.start({
  title: 'Tracking Location',
  body: 'Your route is being recorded',
  channelId: 'location_tracking',
  channelName: 'Location Tracking'
});

await NativeSDK.backgroundGeolocation.startTracking({ accuracy: 'high' });

// Update notification text
let distanceKm = 0;
NativeSDK.on('bgGeo.position', async (pos) => {
  distanceKm += 0.01;
  await NativeSDK.foregroundService.update({
    body: `Distance: ${distanceKm.toFixed(1)}km`
  });
});

// Stop when done
await NativeSDK.backgroundGeolocation.stopTracking();
await NativeSDK.foregroundService.stop();
```
