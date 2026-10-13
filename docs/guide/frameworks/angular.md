# Angular

Build the app into the bundled web folder and include the SDK:

```bash
ng build --configuration production --output-path /path/to/project/assets/www --base-href ./
```

Add `native-sdk.js` (and optionally `native-resilience.js`) from `assets/www/js` of the core to the `scripts` array in `angular.json`, or load it from `index.html`:

```html
<script src="assets/native-sdk.js"></script>
```

## Helper service

`assets/framework-sdks/angular/native-bridge.service.ts` ships an injectable `NativeBridgeService` that wraps `window.NativeSDK` with RxJS and Angular's `NgZone` (calls run outside Angular and their results re-enter the zone). Copy it into your app and inject it:

```typescript
constructor(private native: NativeBridgeService) {}
```

`assets/framework-sdks/rxjs/native-rx.ts` adds ready-made observables such as `nativeEvent$`, `nativeCall$`, `isOnline$`, `backButton$` and `watchPosition$`.

A longer walkthrough (in Persian) is in [Angular integration](/angular-integration).
