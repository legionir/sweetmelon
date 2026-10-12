# Cookie Manager Plugin

Manage WebView cookies and sessions.

## Plugin Name
`cookieManager`

## Methods

### `setCookie`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `domain` | `string` | ✅ | — |
| `name` | `string` | ✅ | — |
| `value` | `string` | ✅ | — |
| `path` | `string` | — | `"/"` |

### `clearCookies`
Clear all WebView cookies.

### `clearSession`
Clear session cookies.

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Set auth cookie for API domain
await NativeSDK.cookieManager.setCookie({
  domain: 'api.myapp.com',
  name: 'auth_token',
  value: 'Bearer eyJhbGc...'
});

// On logout
await NativeSDK.cookieManager.clearCookies();
router.navigate('/login');

// Clear only session
await NativeSDK.cookieManager.clearSession();
```
