# Speech to Text Plugin

Voice recognition / dictation.

## Plugin Name
`speechToText`

## Methods

| Method | Description |
|--------|-------------|
| `initialize` | Initialize engine |
| `startListening` | Start voice recognition |
| `stopListening` | Stop recognition |
| `cancelListening` | Cancel |
| `isAvailable` | Check engine availability; returns `{ available }` |
| `getLocales` | Get supported languages |
| `getInfo` | Returns plugin info: `{ name, version, available, listening }` |

### `startListening`
| Param | Type | Default |
|-------|------|---------|
| `locale` | `string` | device default |
| `listenForSeconds` | `number` | `30` |
| `pauseForSeconds` | `number` | `3` |
| `partialResults` | `bool` | `true` |

## Events
- `speechToText.result` — `{ text, confidence, finalResult, alternates }`
- `speechToText.status` — `{ status, listening }`
- `speechToText.error` — `{ message, permanent }`

## Usage
```javascript
await NativeSDK.speechToText.initialize();
const result = await NativeSDK.speechToText.startListening({ locale: 'fa-IR' });
console.log('You said:', result.text);

// Or with events for real-time
NativeSDK.on('speechToText.result', (data) => {
  searchInput.value = data.text;
});
```
