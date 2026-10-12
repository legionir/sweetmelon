# Connectivity Plugin

Monitor network connectivity status in real-time.

## Plugin Name
`connectivity`

## Methods

### `getStatus`
**Returns:**
```json
{
  "online": true,
  "primary": "wifi",
  "types": ["wifi"],
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### `isOnline`
**Returns:** `{ "online": true }`

### `startWatch`
Start monitoring connectivity changes.

### `stopWatch`
Stop monitoring.

### `getInfo`

**Returns:** `{ watching, eventName }`

## Events

### `connectivity.change`
```json
{
  "online": true,
  "primary": "mobile",
  "types": ["mobile"],
  "timestamp": "..."
}
```

## Usage
```javascript
await NativeSDK.connectivity.startWatch();

NativeSDK.on('connectivity.change', (data) => {
  if (!data.online) {
    showOfflineBanner();
  }
});
```
