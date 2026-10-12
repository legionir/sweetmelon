# Notification Plugin

Display local notifications with channels and actions.

## Plugin Name
`notification`

## Methods

### `show`
| Param | Type | Default |
|-------|------|---------|
| `id` | `number` | random |
| `title` | `string` | `""` |
| `body` | `string` | `""` |
| `channelId` | `string` | `"default"` |
| `channelName` | `string` | `"Default"` |
| `payload` | `string` | — |
| `importance` | `string` | `"high"` |
| `priority` | `string` | `"high"` |
| `ongoing` | `bool` | `false` |
| `autoCancel` | `bool` (dismiss on tap) | `true` |
| `silent` | `bool` | `false` |
| `channelDescription` | `string` | — |

### `cancel` — cancel by `id` (required)
### `cancelAll` — cancel all notifications
### `getActive` — list active notifications
### `getPending` — list pending notifications
### `createChannel` — create Android notification channel
| Param | Type | Default |
|-------|------|---------|
| `channelId` | `string` | ✅ required |
| `channelName` | `string` | ✅ required |
| `description` | `string` | — |
| `importance` | `string` | `"high"` |

### `getInfo`

**Returns:** `{ name, version, initialized, platform }`

## Events

### `notification.tap`
Fired when user taps a notification.
```json
{ "id": 1, "payload": "custom-data", "actionId": null }
```

## Usage
```javascript
await NativeSDK.notification.show({
  title: 'Order Confirmed',
  body: 'Your order #1234 has been confirmed.',
  payload: 'order_1234'
});

NativeSDK.on('notification.tap', (data) => {
  router.navigate('/orders/' + data.payload);
});
```
