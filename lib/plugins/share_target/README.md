# Share Target Plugin

Receive shared content from other apps.

## Plugin Name
`shareTarget`

## Methods

| Method | Returns |
|--------|---------|
| `startListening` | `{ listening: true }` |
| `stopListening` | `{ listening: false }` |
| `getLastShared` | shared data or `{ available: false }` |
| `clearLastShared` | `{ cleared: true }` |
| `getInfo` | `{ name, version, listening, hasSharedData }` |

**Shared Data Format:**
```json
{
  "type": "text",
  "text": "Check out this link!",
  "title": "From Chrome"
}
```
or
```json
{
  "type": "files",
  "paths": ["/path/to/file.jpg"],
  "mimeType": "image/jpeg"
}
```

## Events
| Event | Data |
|-------|------|
| `shareTarget.received` | shared data object |

## Setup (Android)
Add to `AndroidManifest.xml`:
```xml
<intent-filter>
  <action android:name="android.intent.action.SEND"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <data android:mimeType="text/plain"/>
</intent-filter>
<intent-filter>
  <action android:name="android.intent.action.SEND"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <data android:mimeType="image/*"/>
</intent-filter>
```

## Usage
```javascript
await NativeSDK.shareTarget.startListening();

NativeSDK.on('shareTarget.received', async (data) => {
  if (data.type === 'text') {
    // User shared text/URL from another app
    document.getElementById('input').value = data.text;
    await NativeSDK.toast.show('Content received!');
  } else if (data.type === 'files') {
    // User shared image/file
    uploadFiles(data.paths);
  }
});

// Check on app start
const lastShared = await NativeSDK.shareTarget.getLastShared();
if (lastShared.available !== false) {
  handleSharedContent(lastShared);
  await NativeSDK.shareTarget.clearLastShared();
}
```
