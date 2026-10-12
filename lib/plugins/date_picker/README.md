# Date Picker Plugin

Native date and time picker dialogs.

## Plugin Name
`datePicker`

## Methods

### `pickDate`
| Param | Type | Default |
|-------|------|---------|
| `initialDateMs` | `number` | today |
| `firstDateMs` | `number` | 100 years ago |
| `lastDateMs` | `number` | 100 years ahead |
| `title` | `string` | — |

**Returns:**
```json
{ "picked": true, "year": 2024, "month": 1, "day": 15, "dateMs": 1705276800000, "formatted": "2024-01-15" }
```

### `pickTime`
| Param | Type | Default |
|-------|------|---------|
| `initialHour` | `number` | current |
| `initialMinute` | `number` | current |
| `use24h` | `bool` | `true` |
| `title` | `string` | — |

**Returns:**
```json
{ "picked": true, "hour": 14, "minute": 30, "formatted": "14:30" }
```

### `pickDateTime`
Combination of pickDate then pickTime.
| Param | Type | Default |
|-------|------|---------|
| `initialDateMs` | `number` | today |
| `firstDateMs` | `number` | 100 years ago |
| `lastDateMs` | `number` | 100 years ahead |
| `title` | `string` | — |
| `initialHour` | `number` | current |
| `initialMinute` | `number` | current |
| `use24h` | `bool` | `true` |

### `pickDateRange`
| Param | Type |
|-------|------|
| `firstDateMs` | `number` |
| `lastDateMs` | `number` |

**Returns:**
```json
{ "picked": true, "start": { "dateMs": ... }, "end": { "dateMs": ... }, "durationDays": 7 }
```

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Birthday picker
const birth = await NativeSDK.datePicker.pickDate({
  title: 'Select Birth Date',
  lastDateMs: Date.now(),
  firstDateMs: new Date('1900-01-01').getTime()
});
if (birth.picked) form.birthday = birth.formatted;

// Appointment
const dt = await NativeSDK.datePicker.pickDateTime();
if (dt.picked) {
  scheduleAppointment(dt.dateTimeMs);
}

// Hotel booking
const range = await NativeSDK.datePicker.pickDateRange({
  firstDateMs: Date.now()
});
if (range.picked) {
  console.log(`${range.durationDays} nights`);
  bookHotel(range.start.dateMs, range.end.dateMs);
}
```
