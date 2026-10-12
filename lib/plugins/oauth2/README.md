# OAuth2 Plugin

Generic OAuth2 authentication for any provider.

## Plugin Name
`oauth2`

## Methods

### `authorize`
| Param | Type | Required |
|-------|------|----------|
| `authUrl` | `string` | ✅ |
| `clientId` | `string` | ✅ |
| `redirectUri` | `string` | ✅ |
| `scope` | `string` | — |
| `responseType` | `string` | `"code"` |
| `state` | `string` | — |
| `extraParams` | `object` | — |

**Returns:**
```json
{ "success": true, "code": "auth_code_here", "state": "...", "redirectUrl": "..." }
```

### `exchangeCode`
| Param | Type | Required |
|-------|------|----------|
| `tokenUrl` | `string` | ✅ |
| `code` | `string` | ✅ |
| `clientId` | `string` | ✅ |
| `redirectUri` | `string` | ✅ |
| `clientSecret` | `string` | — |
| `codeVerifier` | `string` | — (PKCE) |

**Returns:** `{ accessToken, refreshToken, expiresIn, tokenType, idToken }`

### `refreshToken`
| Param | Type | Required |
|-------|------|----------|
| `tokenUrl` | `string` | ✅ |
| `refreshToken` | `string` | ✅ |
| `clientId` | `string` | ✅ |
| `clientSecret` | `string` | — |

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// GitHub OAuth
const auth = await NativeSDK.oauth2.authorize({
  authUrl: 'https://github.com/login/oauth/authorize',
  clientId: 'your_github_client_id',
  redirectUri: 'sweetmelon://oauth/callback',
  scope: 'user repo'
});

if (auth.success && auth.code) {
  const tokens = await NativeSDK.oauth2.exchangeCode({
    tokenUrl: 'https://github.com/login/oauth/access_token',
    code: auth.code,
    clientId: 'your_github_client_id',
    clientSecret: 'your_secret',
    redirectUri: 'sweetmelon://oauth/callback'
  });
  
  await NativeSDK.secureStorage.set('github_token', tokens.accessToken);
  loadUserProfile(tokens.accessToken);
}

// Discord OAuth with PKCE
const auth = await NativeSDK.oauth2.authorize({
  authUrl: 'https://discord.com/api/oauth2/authorize',
  clientId: 'your_discord_client_id',
  redirectUri: 'sweetmelon://oauth/discord',
  scope: 'identify guilds',
  responseType: 'code'
});

// Refresh token
const newTokens = await NativeSDK.oauth2.refreshToken({
  tokenUrl: 'https://api.example.com/oauth/token',
  refreshToken: await NativeSDK.secureStorage.get('refresh_token'),
  clientId: 'your_client_id'
});
```
