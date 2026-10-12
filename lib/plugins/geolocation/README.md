# Geolocation Plugin

GPS location with real-time watching.

## Plugin Name
`geolocation`

## Methods

### `getCurrentPosition`
| Param | Type | Default |
|-------|------|---------|
| `accuracy` | `string` | `high` |

Accuracy: `lowest`, `low`, `medium`, `high`, `best`, `bestForNavigation`

**Returns:**
```json
{
  "latitude": 35.6892,
  "longitude": 51.3890,
  "altitude": 1200.0,
  "accuracy": 10.5,
  "speed": 0.0,
  "heading": 180.0,
  "timestamp": "..."
}
```

### `watchPosition`
Start continuous position updates.
| Param | Type | Default |
|-------|------|---------|
| `accuracy` | `string` | `high` |
| `distanceFilter` | `number` (meters) | `10` |

### `clearWatch`
Stop watching.

### `checkPermission` / `requestPermission`
### `isLocationEnabled`

## Events

### `geolocation.position`
Fires on each position update during `watchPosition`.

### `geolocation.error`
Fires on location errors.

## Usage
```javascript
const pos = await NativeSDK.geolocation.getCurrentPosition({ accuracy: 'high' });
console.log(`${pos.latitude}, ${pos.longitude}`);

await NativeSDK.geolocation.watchPosition({ distanceFilter: 10 });
NativeSDK.on('geolocation.position', (pos) => {
  updateMap(pos.latitude, pos.longitude);
});
```
