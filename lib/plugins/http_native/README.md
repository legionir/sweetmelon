# HTTP Native Plugin

Native HTTP client with full control over headers, body, and downloads.

## Plugin Name
`http`

## Methods

### `request`
Same as the verb methods below, with the HTTP verb passed explicitly:

| Param | Type | Required | Default |
|-------|------|----------|---------|
| `method` | `string` | — | `GET` |
| `url` | `string` | ✅ | — |
| `headers` | `object` | — | `{}` |
| `body` | `any` | — | — |
| `bodyType` | `string` | — | `auto` |
| `responseType` | `string` | — | `auto` |
| `query` | `object` | — | — |
| `timeoutMs` | `number` | — | `30000` |

### `get`, `post`, `put`, `patch`, `delete`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `url` | `string` | ✅ | — |
| `headers` | `object` | — | `{}` |
| `body` | `any` | — | — |
| `bodyType` | `string` | — | `auto` |
| `responseType` | `string` | — | `auto` |
| `query` | `object` | — | — |
| `timeoutMs` | `number` | — | `30000` |
| `query` | `object` | — | — |
| `timeoutMs` | `number` | — | `30000` |

**bodyType:** `auto`, `json`, `form`
**responseType:** `auto`, `json`, `bytes`, `base64`

**Returns:**
```json
{
  "ok": true,
  "statusCode": 200,
  "headers": {},
  "data": { ... }
}
```

### `download`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `url` | `string` | ✅ | — |
| `fileName` | `string` | — | from URL |
| `baseDir` | `string` | — | `temporary` |
| `path` | `string` | — | `downloads/` |
| `overwrite` | `bool` | — | `true` |
| `headers` | `object` | — | — |
| `query` | `object` | — | — |
| `timeoutMs` | `number` | — | `30000` |

## Usage
```javascript
// GET
const { data } = await NativeSDK.http.get('https://api.example.com/users');

// POST with JSON
const result = await NativeSDK.http.post(
  'https://api.example.com/users',
  { name: 'Ali', email: 'ali@test.com' },
  { bodyType: 'json', responseType: 'json' }
);

// Download
const file = await NativeSDK.http.download({
  url: 'https://example.com/file.pdf',
  fileName: 'report.pdf'
});
```
