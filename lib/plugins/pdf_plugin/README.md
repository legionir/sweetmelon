# PDF Plugin

Generate PDF from text or HTML, print and share.

## Plugin Name
`pdf`

## Methods

### `generateFromText`
| Param | Type | Default |
|-------|------|---------|
| `text` | `string` | — |
| `title` | `string` | `"Document"` |
| `fileName` | `string` | auto |
| `fontSize` | `number` | `12` |

**Returns:** `{ generated: true, path: "...", size: 1234 }`

### `generateFromHtml`
| Param | Type |
|-------|------|
| `html` | `string` |
| `fileName` | `string` |

### `print`
| Param | Type | Description |
|-------|------|-------------|
| `path` | `string` | Print existing PDF |
| `html` | `string` | Print from HTML |
| `name` | `string` | Print job name |

### `share`
Share PDF file via native share sheet.
| Param | Type | Required |
|-------|------|----------|
| `path` | `string` | ✅ |

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Generate from text
const pdf = await NativeSDK.pdf.generateFromText(
  'This is my report content...',
  { title: 'Monthly Report', fontSize: 14 }
);

// Generate from HTML
const invoice = await NativeSDK.pdf.generateFromHtml({
  html: '<h1>Invoice #123</h1><p>Total: $500</p>'
});

// Print
await NativeSDK.pdf.print({ path: pdf.path, name: 'Report' });

// Share
await NativeSDK.pdf.share(pdf.path);
```
