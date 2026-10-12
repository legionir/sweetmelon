# Email Composer Plugin

Open email compose window.

## Plugin Name
`emailComposer`

## Methods

### `compose`
| Param | Type | Required |
|-------|------|----------|
| `to` | `string \| string[]` | ✅ |
| `subject` | `string` | — |
| `body` | `string` | — |
| `cc` | `string \| string[]` | — |
| `bcc` | `string \| string[]` | — |

### `canCompose`
**Returns:** `{ available: bool }`

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Support email
await NativeSDK.emailComposer.compose({
  to: 'support@myapp.com',
  subject: 'Support Request',
  body: `
App Version: ${appVersion}
Device: ${deviceModel}

Issue Description:
`
});

// Bug report with CC
await NativeSDK.emailComposer.compose({
  to: 'bugs@myapp.com',
  cc: 'team@myapp.com',
  subject: 'Bug Report #' + Date.now(),
  body: await generateBugReport()
});

// Multiple recipients
await NativeSDK.emailComposer.compose({
  to: ['sales@myapp.com', 'info@myapp.com'],
  subject: 'Quote Request'
});

// Check availability first
const { available } = await NativeSDK.emailComposer.canCompose();
if (!available) {
  await NativeSDK.toast.show('No email app installed');
}
```
