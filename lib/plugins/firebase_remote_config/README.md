# Firebase Remote Config Plugin

Control app behavior without releasing new versions.

## Plugin Name
`firebaseRemoteConfig`

## Methods

### `initialize`
| Param | Type | Default |
|-------|------|---------|
| `minimumFetchIntervalMs` | `number` | `3600000` (1hr) |
| `fetchTimeoutMs` | `number` | `60000` |
| `defaults` | `object` | — |

### `fetchAndActivate` — Fetch + activate in one call
### `fetch` — Fetch latest values without activating; returns `{ fetched, error? }`
### `activate` — Apply fetched values; returns `{ activated }`
### `getString` / `getInt` / `getDouble` / `getBool` / `getJson`
| Param | Type | Required |
|-------|------|----------|
| `key` | `string` | ✅ |

### `getAll` — Get all config values
### `setDefaults` — `defaults` (object ✅)
### `getLastFetchStatus`
### `getLastFetchTime` — returns `{ timestamp, ms }`
### `setConfigSettings`
| Param | Type | Default |
|-------|------|---------|
| `fetchTimeoutMs` | `number` | `60000` |
| `minimumFetchIntervalMs` | `number` | `3600000` (1hr) |

### `getInfo`

**Returns:** `{ name, version, initialized, lastFetchStatus }`

## Events
| Event | Data |
|-------|------|
| `remoteConfig.updated` | `{ timestamp }` |

## Usage
```javascript
// Initialize with defaults
await NativeSDK.firebaseRemoteConfig.initialize({
  minimumFetchIntervalMs: 3600000,
  defaults: {
    feature_chat: false,
    max_upload_mb: 10,
    api_url: 'https://api.myapp.com',
    welcome_message: 'Welcome!'
  }
});

// Fetch and apply
const { updated } = await NativeSDK.firebaseRemoteConfig.fetchAndActivate();
if (updated) console.log('Config updated');

// Use values
const { value: chatEnabled } = await NativeSDK.firebaseRemoteConfig.getBool('feature_chat');
const { value: apiUrl } = await NativeSDK.firebaseRemoteConfig.getString('api_url');
const { value: maxUpload } = await NativeSDK.firebaseRemoteConfig.getInt('max_upload_mb');

if (chatEnabled) loadChatModule();

// Feature flags (A/B testing)
const { value: variant } = await NativeSDK.firebaseRemoteConfig.getString('onboarding_variant');
switch (variant) {
  case 'A': showOnboardingA(); break;
  case 'B': showOnboardingB(); break;
  default: showOnboardingDefault();
}
```
