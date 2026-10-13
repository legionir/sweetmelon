# React

Build your app and copy the output into `assets/www/` of the project, and include `js/native-sdk.js` in your HTML:

```bash
GENERATE_SOURCEMAP=false npm run build
cp -r build/* /path/to/project/assets/www/
```

## Hooks

`assets/framework-sdks/react/useNative.ts` contains hooks over the global `NativeSDK`. Copy the file into your app:

| Hook | Purpose |
| --- | --- |
| `useNativeSDK()` | Waits for the bridge; returns `{ ready, error, sdk }` |
| `useNativeEvent(name, handler, deps)` | Subscribes to a native event |
| `useConnectivity()` | Online state and connection type |
| `useNativeStorage(key, initial)` | State that persists in native storage |
| `useDeviceInfo()` | Device information |
| `useBackButton(handler)` | Android back button |
| `useGeolocation()` | Position |
| `useKeyboard()`, `useAppLifecycle()`, `usePermission(name)` | Keyboard, app state, permissions |

```tsx
import { useNativeSDK } from './useNative';

export function Home() {
  const { ready, error, sdk } = useNativeSDK();
  if (error) return <p>Bridge unavailable</p>;
  if (!ready) return <p>Loading…</p>;
  return <button onClick={() => sdk.toast.show('Hello')}>Toast</button>;
}
```

The hooks assume the plugins they use (for example `connectivity` or `geolocation`) are enabled in `sweetmelon.yaml`.
