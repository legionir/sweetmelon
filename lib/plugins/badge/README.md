# Badge Plugin

Manage app icon badge count.

## Plugin Name
`badge`

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `set` | `count: number` | `{ count, set }` |
| `clear` | — | `{ count: 0 }` |
| `increase` | `by?: number` (default 1) | `{ count }` |
| `decrease` | `by?: number` (default 1) | `{ count }` |
| `get` | — | `{ count }` |
| `isSupported` | — | `{ supported: bool }` |
| `getInfo` | — | `{ name, version, count }` |

## Usage
```javascript
// Unread message count
const { supported } = await NativeSDK.badge.isSupported();
if (supported) {
  await NativeSDK.badge.set(unreadCount);
}

// New message arrived
NativeSDK.on('push.received', async () => {
  await NativeSDK.badge.increase(1);
});

// User opened app
NativeSDK.on('app.lifecycle.change', async (state) => {
  if (state.state === 'resumed') {
    await NativeSDK.badge.clear();
  }
});
```
