# Dialog Plugin

Native dialog windows for alerts, confirmations, and prompts.

## Plugin Name
`dialog`

## Methods

### `alert`
| Param | Type | Default |
|-------|------|---------|
| `message` | `string` | ✅ |
| `title` | `string` | — |
| `buttonTitle` | `string` | `"OK"` |

**Returns:** `{ dismissed: true }`

### `confirm`
| Param | Type | Default |
|-------|------|---------|
| `message` | `string` | ✅ |
| `title` | `string` | — |
| `okButtonTitle` | `string` | `"OK"` |
| `cancelButtonTitle` | `string` | `"Cancel"` |

**Returns:** `{ confirmed: true/false }`

### `prompt`
| Param | Type | Default |
|-------|------|---------|
| `message` | `string` | — |
| `title` | `string` | — |
| `placeholder` | `string` | — |
| `defaultValue` | `string` | — |
| `inputType` | `string` | `"text"` |
| `maxLength` | `number` | — |
| `okButtonTitle` | `string` | `"OK"` |
| `cancelButtonTitle` | `string` | `"Cancel"` |

**inputType:** `text`, `number`, `phone`, `email`, `url`, `multiline`, `password`

**Returns:** `{ cancelled: false, value: "user input" }`

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Alert
await NativeSDK.dialog.alert({
  title: 'Success',
  message: 'Your data has been saved.'
});

// Confirm
const { confirmed } = await NativeSDK.dialog.confirm({
  title: 'Delete',
  message: 'Are you sure you want to delete this item?',
  okButtonTitle: 'Delete',
  cancelButtonTitle: 'Cancel'
});
if (confirmed) deleteItem();

// Prompt
const { cancelled, value } = await NativeSDK.dialog.prompt({
  title: 'Enter Name',
  placeholder: 'Your full name',
  inputType: 'text'
});
if (!cancelled && value) setUserName(value);
```
