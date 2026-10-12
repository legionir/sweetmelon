# Calendar Plugin

Read and write device calendar events.

## Plugin Name
`calendar`

## Methods

### `getCalendars`
**Returns:**
```json
{
  "calendars": [
    { "id": "1", "name": "Personal", "accountName": "user@gmail.com", "isReadOnly": false }
  ]
}
```

### `getEvents`
| Param | Type | Default |
|-------|------|---------|
| `calendarId` | `string` | ✅ |
| `startMs` | `number` | now |
| `endMs` | `number` | — |
| `daysAhead` | `number` | `30` |

### `createEvent`
| Param | Type | Required |
|-------|------|----------|
| `calendarId` | `string` | ✅ |
| `title` | `string` | ✅ |
| `startMs` | `number` | ✅ |
| `endMs` | `number` | ✅ |
| `description` | `string` | — |
| `location` | `string` | — |
| `allDay` | `bool` | `false` |

### `deleteEvent`
| Param | Type | Required |
|-------|------|----------|
| `calendarId` | `string` | ✅ |
| `eventId` | `string` | ✅ |

### `hasPermission` / `requestPermission`

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Get calendars
await NativeSDK.calendar.requestPermission();
const { calendars } = await NativeSDK.calendar.getCalendars();
const myCalendar = calendars.find(c => c.name === 'Personal');

// Get upcoming events
const { events } = await NativeSDK.calendar.getEvents(myCalendar.id, {
  daysAhead: 7
});
events.forEach(e => console.log(e.title, new Date(e.startMs)));

// Create event
const { eventId } = await NativeSDK.calendar.createEvent({
  calendarId: myCalendar.id,
  title: 'Team Meeting',
  description: 'Weekly sync',
  startMs: Date.now() + 3600000,
  endMs: Date.now() + 7200000,
  location: 'Conference Room 3'
});

// Delete event
await NativeSDK.calendar.deleteEvent(myCalendar.id, eventId);
```
