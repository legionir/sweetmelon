# Vue

Build your app and copy the output into `assets/www/` of the project, and include `js/native-sdk.js` in your HTML:

```bash
npm run build
cp -r dist/* /path/to/project/assets/www/
```

## Composables

`assets/framework-sdks/vue/useNative.ts` provides composables over the global `NativeSDK`. Copy the file into your app:

| Composable | Purpose |
| --- | --- |
| `useNativeSDK()` | Waits for the bridge; returns `{ ready, error, sdk }` as refs |
| `useNativeEvent(name, handler)` | Subscribes to a native event for the component's lifetime |
| `useConnectivity()` | Online state |
| `useNativeStorage(key, initial)` | State that persists in native storage |
| `useBackButton(handler)` | Android back button |
| `useGeolocation()` | Position |

```vue
<script setup lang="ts">
import { useNativeSDK } from './useNative';
const { ready, sdk } = useNativeSDK();
</script>

<template>
  <button :disabled="!ready" @click="sdk.toast.show('Hello')">Toast</button>
</template>
```
