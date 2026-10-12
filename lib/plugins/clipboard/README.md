# Clipboard Plugin

Read and write system clipboard.

## Plugin Name
`clipboard`

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `writeText` | `text: string` | `{ written: true }` |
| `readText` | — | `{ text: "..." }` |
| `hasText` | — | `{ hasText: true }` |
| `clear` | — | `{ cleared: true }` |

## Usage
```javascript
await NativeSDK.clipboard.writeText('Hello World');
const { text } = await NativeSDK.clipboard.readText();
```
