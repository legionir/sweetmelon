# In-App Browser Plugin

Open external web pages inside the app (for OAuth, payment, etc).

## Plugin Name
`inAppBrowser`

## Methods

### `open`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `url` | `string` | ✅ | — |
| `title` | `string` | — | `""` |
| `showToolbar` | `bool` | — | `true` |
| `closeOnUrlMatch` | `string` | — | — |

**Returns** (when browser is closed):
```json
{ "closed": true, "reason": "user_closed", "lastUrl": "..." }
```

### `getInfo`

**Returns:** `{ name, version }`

## Events
- `inAppBrowser.loadStop` — `{ url }`
- `inAppBrowser.error` — `{ url, code, message }`

## Usage
```javascript
// OAuth flow
const result = await NativeSDK.inAppBrowser.open({
  url: 'https://accounts.google.com/o/oauth2/v2/auth?...',
  title: 'Sign in with Google',
  closeOnUrlMatch: 'myapp://callback'
});

// result.lastUrl contains the callback URL with token
const token = extractTokenFromUrl(result.lastUrl);
```
