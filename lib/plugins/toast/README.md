# Toast Plugin

Native toast notification messages.

## Plugin Name
`toast`

## Methods

### `show`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `text` | `string` | ✅ | — |
| `duration` | `string` | — | `"short"` |
| `position` | `string` | — | `"bottom"` |
| `backgroundColor` | `string` | — | `"#323232"` |
| `textColor` | `string` | — | `"#FFFFFF"` |

**duration:** `"short"` (2s) or `"long"` (4s)
**position:** `"bottom"` or `"top"`

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Simple
await NativeSDK.toast.show('Saved successfully!');

// Custom
await NativeSDK.toast.show('Error occurred', {
  duration: 'long',
  position: 'top',
  backgroundColor: '#F44336',
  textColor: '#FFFFFF'
});

await NativeSDK.toast.show('✓ Copied to clipboard', {
  duration: 'short',
  backgroundColor: '#4CAF50'
});
```
