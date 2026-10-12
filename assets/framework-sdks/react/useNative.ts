import { useState, useEffect, useCallback, useRef } from 'react';

declare const NativeSDK: any;

// ── Core Hook ──

export function useNativeSDK() {
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let mounted = true;

    NativeSDK.waitForReady(10000)
      .then(() => { if (mounted) setReady(true); })
      .catch((e: Error) => { if (mounted) setError(e); });

    return () => { mounted = false; };
  }, []);

  return { ready, error, sdk: NativeSDK };
}

// ── Event Hook ──

export function useNativeEvent<T = any>(
  eventName: string,
  handler: (data: T) => void,
  deps: any[] = []
) {
  const handlerRef = useRef(handler);
  handlerRef.current = handler;

  useEffect(() => {
    const unsub = NativeSDK.on(eventName, (data: T) => {
      handlerRef.current(data);
    });
    return unsub;
  }, [eventName, ...deps]);
}

// ── Connectivity Hook ──

export function useConnectivity() {
  const [online, setOnline] = useState(true);
  const [networkType, setNetworkType] = useState<string>('unknown');

  useEffect(() => {
    NativeSDK.connectivity.getStatus()
      .then((status: any) => {
        setOnline(status.online);
        setNetworkType(status.primary || 'unknown');
      })
      .catch(console.error);

    NativeSDK.connectivity.startWatch();
  }, []);

  useNativeEvent('connectivity.change', (data: any) => {
    setOnline(data.online);
    setNetworkType(data.primary || 'unknown');
  });

  return { online, networkType };
}

// ── Storage Hook ──

export function useNativeStorage<T>(
  key: string,
  defaultValue: T
): [T, (value: T) => Promise<void>, boolean] {
  const [value, setValue] = useState<T>(defaultValue);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    NativeSDK.storage.get(key)
      .then((stored: T | null) => {
        if (stored !== null && stored !== undefined) {
          setValue(stored);
        }
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, [key]);

  const setStored = useCallback(async (newValue: T) => {
    await NativeSDK.storage.set(key, newValue);
    setValue(newValue);
  }, [key]);

  return [value, setStored, loading];
}

// ── Device Info Hook ──

export function useDeviceInfo() {
  const [info, setInfo] = useState<any>(null);

  useEffect(() => {
    NativeSDK.deviceInfo.getAll()
      .then(setInfo)
      .catch(console.error);
  }, []);

  return info;
}

// ── Back Button Hook ──

export function useBackButton(
  handler: () => boolean | void,
  enabled = true
) {
  const handlerRef = useRef(handler);
  handlerRef.current = handler;

  useEffect(() => {
    if (!enabled) return;

    NativeSDK.backButton.enableIntercept();

    const unsub = NativeSDK.on('backButton.pressed', () => {
      const handled = handlerRef.current();
      if (!handled) {
        NativeSDK.backButton.exitApp();
      }
    });

    return () => {
      unsub();
      NativeSDK.backButton.disableIntercept();
    };
  }, [enabled]);
}

// ── Geolocation Hook ──

export function useGeolocation(watch = false) {
  const [position, setPosition] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const getCurrentPosition = useCallback(async () => {
    setLoading(true);
    try {
      const pos = await NativeSDK.geolocation.getCurrentPosition({
        accuracy: 'high',
      });
      setPosition(pos);
      setError(null);
    } catch (e: any) {
      setError(e.message || 'Location error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!watch) return;

    NativeSDK.geolocation.watchPosition({ accuracy: 'high' });

    const unsub1 = NativeSDK.on('geolocation.position', (pos: any) => {
      setPosition(pos);
    });

    const unsub2 = NativeSDK.on('geolocation.error', (err: any) => {
      setError(err.message);
    });

    return () => {
      NativeSDK.geolocation.clearWatch();
      unsub1();
      unsub2();
    };
  }, [watch]);

  return { position, error, loading, getCurrentPosition };
}

// ── Keyboard Hook ──

export function useKeyboard() {
  const [visible, setVisible] = useState(false);
  const [height, setHeight] = useState(0);

  useEffect(() => {
    NativeSDK.keyboard.startWatch();

    const unsub = NativeSDK.on('keyboard.change', (data: any) => {
      setVisible(data.visible);
      setHeight(data.height || 0);
    });

    return () => {
      NativeSDK.keyboard.stopWatch();
      unsub();
    };
  }, []);

  return { visible, height };
}

// ── App Lifecycle Hook ──

export function useAppLifecycle(callbacks: {
  onPause?: () => void;
  onResume?: () => void;
  onBackground?: () => void;
  onForeground?: () => void;
}) {
  useNativeEvent('app.lifecycle.change', (data: any) => {
    switch (data.state) {
      case 'paused':
      case 'inactive':
        callbacks.onPause?.();
        callbacks.onBackground?.();
        break;
      case 'resumed':
        callbacks.onResume?.();
        callbacks.onForeground?.();
        break;
    }
  });
}

// ── Permission Hook ──

export function usePermission(permissionName: string) {
  const [status, setStatus] = useState<string>('unknown');
  const [granted, setGranted] = useState(false);

  const check = useCallback(async () => {
    const result = await NativeSDK.permission.check(permissionName);
    setStatus(result.status);
    setGranted(result.granted);
    return result;
  }, [permissionName]);

  const request = useCallback(async () => {
    const result = await NativeSDK.permission.request(permissionName);
    setStatus(result.status);
    setGranted(result.granted);
    return result;
  }, [permissionName]);

  useEffect(() => { check(); }, [check]);

  return { status, granted, check, request };
}
