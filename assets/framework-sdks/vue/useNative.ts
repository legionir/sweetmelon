import {
  ref, reactive, onMounted, onUnmounted, computed, Ref
} from 'vue';

declare const NativeSDK: any;

// ── Core ──

export function useNativeSDK() {
  const ready = ref(false);
  const error = ref<Error | null>(null);

  onMounted(async () => {
    try {
      await NativeSDK.waitForReady(10000);
      ready.value = true;
    } catch (e) {
      error.value = e as Error;
    }
  });

  return { ready, error, sdk: NativeSDK };
}

// ── Event ──

export function useNativeEvent<T = any>(
  eventName: string,
  handler: (data: T) => void
) {
  let unsub: (() => void) | null = null;

  onMounted(() => {
    unsub = NativeSDK.on(eventName, handler);
  });

  onUnmounted(() => {
    unsub?.();
  });
}

// ── Connectivity ──

export function useConnectivity() {
  const online = ref(true);
  const networkType = ref('unknown');

  onMounted(async () => {
    const status = await NativeSDK.connectivity.getStatus();
    online.value = status.online;
    networkType.value = status.primary || 'unknown';
    await NativeSDK.connectivity.startWatch();
  });

  useNativeEvent('connectivity.change', (data: any) => {
    online.value = data.online;
    networkType.value = data.primary || 'unknown';
  });

  onUnmounted(() => {
    NativeSDK.connectivity.stopWatch();
  });

  return { online: readonly(online), networkType: readonly(networkType) };
}

// ── Storage ──

export function useNativeStorage<T>(key: string, defaultValue: T) {
  const value = ref<T>(defaultValue) as Ref<T>;
  const loading = ref(true);

  onMounted(async () => {
    try {
      const stored = await NativeSDK.storage.get(key);
      if (stored !== null && stored !== undefined) {
        value.value = stored;
      }
    } finally {
      loading.value = false;
    }
  });

  const save = async (newValue: T) => {
    await NativeSDK.storage.set(key, newValue);
    value.value = newValue;
  };

  return { value, loading, save };
}

// ── Back Button ──

export function useBackButton(
  handler: () => boolean | void,
  enabled = true
) {
  onMounted(async () => {
    if (!enabled) return;
    await NativeSDK.backButton.enableIntercept();
  });

  useNativeEvent('backButton.pressed', () => {
    if (!enabled) return;
    const handled = handler();
    if (!handled) {
      NativeSDK.backButton.exitApp();
    }
  });

  onUnmounted(async () => {
    await NativeSDK.backButton.disableIntercept();
  });
}

// ── Geolocation ──

export function useGeolocation(watch = false) {
  const position = ref<any>(null);
  const error = ref<string | null>(null);
  const loading = ref(false);

  const getCurrentPosition = async () => {
    loading.value = true;
    try {
      position.value = await NativeSDK.geolocation.getCurrentPosition({
        accuracy: 'high',
      });
      error.value = null;
    } catch (e: any) {
      error.value = e.message;
    } finally {
      loading.value = false;
    }
  };

  onMounted(async () => {
    if (watch) {
      await NativeSDK.geolocation.watchPosition({ accuracy: 'high' });
    }
  });

  useNativeEvent('geolocation.position', (data: any) => {
    if (watch) position.value = data;
  });

  useNativeEvent('geolocation.error', (data: any) => {
    error.value = data.message;
  });

  onUnmounted(async () => {
    if (watch) await NativeSDK.geolocation.clearWatch();
  });

  return {
    position: readonly(position),
    error: readonly(error),
    loading: readonly(loading),
    getCurrentPosition,
  };
}

function readonly<T>(ref: Ref<T>) { return ref; }
