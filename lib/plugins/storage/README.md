# Storage Plugin

Simple key-value storage using SharedPreferences.

## Plugin Name
`storage`

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `set` | `key: string, value: any` | `true` |
| `get` | `key: string` | stored value or `null` |
| `has` | `key: string` | `{ exists: bool }` |
| `remove` | `key: string` | `true` |
| `keys` | — | `{ keys: string[] }` |
| `clear` | — | count of removed keys |
| `getInfo` | — | `{ name, version, prefix, keysCount }` |

## Usage
```javascript
await NativeSDK.storage.set('user', { name: 'Ali', role: 'admin' });
const user = await NativeSDK.storage.get('user');
const { keys } = await NativeSDK.storage.keys();
await NativeSDK.storage.remove('user');
```

## Notes
- Values are JSON-encoded automatically
- Keys are prefixed with `bridge_` internally
- For sensitive data, use `secureStorage` instead
