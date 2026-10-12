# Intent / Deep Link Plugin

Open URLs, apps, and receive deep links.

## Plugin Name
`intent`

## Methods

### `openUrl`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `url` | `string` | ✅ | — |
| `mode` | `string` | — | `external` |

**Modes:** `external`, `inApp`, `platform`, `externalNonBrowser`

### `canOpenUrl`
Check if URL can be opened.
| Param | Type | Required |
|-------|------|----------|
| `url` | `string` | ✅ |

### `getInitialLink` / `getLatestLink`
Get deep link that opened the app.

### `startListening` / `stopListening`
Listen for incoming deep links.

## Events

### `intent.deepLink`
```json
{ "url": "sweetmelon://product/123", "timestamp": "..." }
```

## Supported URL Schemes
`https://`, `http://`, `tel:`, `sms:`, `smsto:`, `mailto:`, `geo:`, `market:`, `sweetmelon://`

## Usage
```javascript
await NativeSDK.intent.openUrl('tel:+989123456789');
await NativeSDK.intent.openUrl('mailto:test@example.com');
await NativeSDK.intent.openUrl('https://flutter.dev');

NativeSDK.on('intent.deepLink', (data) => {
  router.navigate(data.url);
});
```
