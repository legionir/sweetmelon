# QR Scanner Plugin

Scan QR codes and barcodes using native camera.

## Plugin Name
`qrScanner`

## Methods

### `scan`
| Param | Type | Default |
|-------|------|---------|
| `timeoutMs` | `number` | `60000` |

**Returns:**
```json
{
  "scanned": true,
  "value": "https://example.com",
  "format": "qr",
  "type": "url",
  "timestamp": "..."
}
```

Content types: `url`, `phone`, `email`, `sms`, `wifi`, `geo`, `vcard`, `text`

Supported formats: QR, EAN-13, EAN-8, Code128, Code39, UPC-A, UPC-E, ITF, PDF417, Aztec, DataMatrix

### `getInfo`

**Returns:** `{ name, version, supportedFormats }`

## Events
### `qrScanner.scanned`

## Usage
```javascript
const result = await NativeSDK.qrScanner.scan({ timeoutMs: 30000 });
if (result.scanned) {
  if (result.type === 'url') {
    NativeSDK.intent.openUrl(result.value);
  }
}
```
