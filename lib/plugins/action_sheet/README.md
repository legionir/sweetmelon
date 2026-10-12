# Action Sheet Plugin

Native bottom sheet with action options.

## Plugin Name
`actionSheet`

## Methods

### `show`
| Param | Type | Required |
|-------|------|----------|
| `options` | `array` | ✅ |
| `title` | `string` | — |
| `message` | `string` | — |
| `cancelText` | `string` | `"Cancel"` |
| `destructiveIndex` | `number` | — |

**Option object:**
```json
{ "title": "Delete", "icon": "delete", "subtitle": "Cannot be undone" }
```

**Available icons:** `delete`, `edit`, `share`, `copy`, `camera`, `photo`, `file`, `download`, `upload`, `settings`, `info`, `warning`

**Returns:**
```json
{ "selected": true, "index": 2, "value": "Delete", "option": {...} }
```

### `getInfo`

**Returns:** `{ name, version }`

## Usage
```javascript
// File actions
const result = await NativeSDK.actionSheet.show({
  title: 'File Options',
  options: [
    { title: 'Open', icon: 'file' },
    { title: 'Share', icon: 'share' },
    { title: 'Download', icon: 'download' },
    { title: 'Delete', icon: 'delete' }
  ],
  destructiveIndex: 3
});

if (result.selected) {
  switch (result.index) {
    case 0: openFile(); break;
    case 1: shareFile(); break;
    case 2: downloadFile(); break;
    case 3: deleteFile(); break;
  }
}

// Photo source picker
const source = await NativeSDK.actionSheet.show({
  options: [
    { title: 'Take Photo', icon: 'camera' },
    { title: 'Choose from Gallery', icon: 'photo' }
  ]
});
if (source.selected) {
  if (source.index === 0) NativeSDK.camera.takePhoto();
  else NativeSDK.camera.pickFromGallery();
}
```
