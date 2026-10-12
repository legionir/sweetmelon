# Encryption Plugin

AES encryption, SHA/MD5 hashing, HMAC, and random bytes.

## Plugin Name
`encryption`

## Methods

### AES Encryption
| Method | Args | Returns |
|--------|------|---------|
| `generateAesKey` | `bits? (128/256)` | `{ key, iv }` (base64) |
| `aesEncrypt` | `data, key, iv?` | `{ encrypted, iv }` (base64) |
| `aesDecrypt` | `data, key, iv` | `{ decrypted }` |
| `getInfo` | — | `{ name, version, algorithms }` |

### Hashing
| Method | Args | Returns |
|--------|------|---------|
| `hashSha256` | `data` | `{ hash, base64 }` |
| `hashSha512` | `data` | `{ hash, base64 }` |
| `hashMd5` | `data` | `{ hash, base64 }` |
| `hmacSha256` | `data, key` | `{ hmac, base64 }` |

### Utility
| Method | Args | Returns |
|--------|------|---------|
| `generateRandomBytes` | `length?` | `{ hex, base64 }` |
| `base64Encode` | `data` | `{ encoded }` |
| `base64Decode` | `data` | `{ decoded }` |

## Usage
```javascript
// Generate key
const { key, iv } = await NativeSDK.encryption.generateAesKey(256);

// Encrypt
const { encrypted } = await NativeSDK.encryption.aesEncrypt('Hello World', key, iv);

// Decrypt
const { decrypted } = await NativeSDK.encryption.aesDecrypt(encrypted, key, iv);

// Hash
const { hash } = await NativeSDK.encryption.hashSha256('password123');

// HMAC for API signing
const { hmac } = await NativeSDK.encryption.hmacSha256(
  JSON.stringify(requestBody),
  apiSecret
);
```
