# Secure Storage Plugin

AES-encrypted key-value storage for sensitive data (tokens, passwords, etc).

## Plugin Name
`secureStorage`

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `set` | `key, value` | `{ written: true }` |
| `get` | `key` | `{ value: ..., found: bool }` |
| `has` | `key` | `{ exists: bool }` |
| `remove` | `key` | `{ removed: true }` |
| `keys` | — | `{ keys: [], count: n }` |
| `clear` | — | `{ cleared: n }` |
| `getInfo` | — | `{ name, version, encrypted, prefix }` |

## Usage
```javascript
await NativeSDK.secureStorage.set('auth_token', 'eyJhbGciOiJIUzI1...');
const { value } = await NativeSDK.secureStorage.get('auth_token');
```

## Notes
- Uses Android EncryptedSharedPreferences
- Uses iOS Keychain
- Keys prefixed with `sec_` internally
