# Vanilla JavaScript

No build step is needed. Put your files in `assets/www/` with `index.html` as the entry point and include the SDK:

```html
<script src="js/native-sdk.js"></script>
<script src="js/native-resilience.js"></script> <!-- optional -->
<script src="js/app.js"></script>
```

```javascript
// app.js
NativeSDK.waitForReady().then(async () => {
  const info = await NativeSDK.deviceInfo.getAll();
  console.log(info.device.model);

  NativeSDK.on('connectivity.change', (data) => console.log(data));
});
```

`waitForReady()` rejects when the page is opened outside the app (for example in a desktop browser), so you can fall back to web behavior. The default test suite in `assets/www` is a complete example: `index.html`, `js/app.js` and `js/ui.js` call every enabled plugin.
