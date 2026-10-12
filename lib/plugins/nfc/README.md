# NFC Plugin

Read and write NFC tags.

## Plugin Name
`nfc`

## Methods

| Method | Args | Description |
|--------|------|-------------|
| `isAvailable` | — | Check NFC support |
| `startSession` | `readOnce` (bool, default true) | Start NFC read session |
| `stopSession` | — | Stop session |
| `writeText` | `text` ✅ | Write text to NFC tag |
| `writeUri` | `uri` ✅ | Write URL to NFC tag |
| `getInfo` | — | Returns plugin info: `{ name, version, sessionActive }` |

## Events
- `nfc.tagDiscovered` — `{ id, type, records, isWritable }`
- `nfc.error` — `{ message }`

## Usage
```javascript
const tag = await NativeSDK.nfc.startSession({ readOnce: true });
console.log('Tag ID:', tag.id);
console.log('Content:', tag.records[0]?.payloadString);

// Write
await NativeSDK.nfc.writeText('Hello NFC');
await NativeSDK.nfc.writeUri('https://example.com');
```
