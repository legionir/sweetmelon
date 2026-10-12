# Document Scanner Plugin

Scan documents with automatic edge detection and crop.

## Plugin Name
`documentScanner`

## Methods

### `scan`
| Param | Type | Default |
|-------|------|---------|
| `maxPages` | `number` | `1` |
| `allowGallery` | `bool` | `false` |

**Returns:**
```json
{
  "scanned": true,
  "pages": [
    { "page": 1, "path": "/...", "size": 234567 }
  ],
  "count": 1
}
```

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// Scan single document
const { pages, scanned } = await NativeSDK.documentScanner.scan();
if (scanned) {
  displayDocument(pages[0].path);
}

// Multi-page scan
const { pages } = await NativeSDK.documentScanner.scan({ maxPages: 5 });
if (pages.length > 0) {
  // Create PDF from scanned pages
  const pdf = await NativeSDK.pdf.generateFromHtml({
    html: pages.map(p => `<img src="${p.path}" style="width:100%">`).join(''),
    fileName: 'scanned_document.pdf'
  });
  await NativeSDK.share.shareFiles([pdf.path]);
}

// Scan with gallery import
const { pages } = await NativeSDK.documentScanner.scan({
  maxPages: 3,
  allowGallery: true
});

// Upload scanned document
if (pages.length > 0) {
  const compressed = await NativeSDK.fileCompressor.compressImage(
    pages[0].path, { quality: 85 }
  );
  await uploadToServer(compressed.outputPath);
}
```
