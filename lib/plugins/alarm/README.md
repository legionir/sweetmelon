# Alarm Plugin

Schedule timer-based alarms with events.

## Plugin Name
`alarm`

## Methods

### `set`
| Param | Type | Required |
|-------|------|----------|
| `alarmId` | `string` | — (auto) |
| `delayMs` | `number` | ✅ (or atMs) |
| `atMs` | `number` | ✅ (or delayMs) |
| `title` | `string` | — |
| `body` | `string` | — |
| `repeating` | `bool` | `false` |
| `intervalMs` | `number` | — (if repeating) |
| `payload` | `any` | — |

### `cancel` / `getAlarm` — `alarmId` required
### `cancelAll` / `getAllAlarms`

### `getInfo`

**Returns:** `{ name, version, activeAlarms }`

## Events
| Event | Data |
|-------|------|
| `alarm.fired` | `{ alarmId, title, body, payload, firedAt }` |

## Usage
```javascript
// One-time alarm (5 minutes from now)
await NativeSDK.alarm.set({
  alarmId: 'break_reminder',
  delayMs: 5 * 60 * 1000,
  title: 'Take a Break!',
  body: 'Time for a 5-minute break.',
  payload: { type: 'break', duration: 5 }
});

// Alarm at specific time
const tomorrow9am = new Date();
tomorrow9am.setDate(tomorrow9am.getDate() + 1);
tomorrow9am.setHours(9, 0, 0, 0);

await NativeSDK.alarm.set({
  alarmId: 'morning_brief',
  atMs: tomorrow9am.getTime(),
  title: 'Morning Briefing',
  payload: { screen: '/briefing' }
});

// Repeating sync every 30 minutes
await NativeSDK.alarm.set({
  alarmId: 'sync',
  delayMs: 0,
  repeating: true,
  intervalMs: 30 * 60 * 1000,
  title: 'Syncing data...'
});

// Handle alarm
NativeSDK.on('alarm.fired', async (data) => {
  if (data.payload?.screen) {
    router.navigate(data.payload.screen);
  }
  await NativeSDK.notification.show({
    title: data.title,
    body: data.body
  });
});
```
