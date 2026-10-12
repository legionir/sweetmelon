# App Lifecycle Plugin

Monitor app lifecycle state changes (pause, resume, background, etc).

## Plugin Name
`appLifecycle`

## Methods

### `getState`
Get current app state.

**Returns:**
```json
{ "state": "resumed" }
```

Possible states: `resumed`, `inactive`, `paused`, `detached`, `hidden`

### `enableEvents`
Enable lifecycle change events.

**Returns:** `{ "enabled": true }`

### `disableEvents`
Disable lifecycle change events.

**Returns:** `{ "enabled": false }`

### `getInfo`
Get plugin info including current state and event status.

## Events

### `app.lifecycle.change`
Fired when app state changes.
```json
{
  "state": "paused",
  "previousState": "resumed",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

## Usage
```javascript
// Get current state
const { state } = await NativeSDK.appLifecycle.getState();

// Listen to changes
NativeSDK.on('app.lifecycle.change', (data) => {
  if (data.state === 'paused') {
    saveFormData();
  }
  if (data.state === 'resumed') {
    refreshData();
  }
});
```
