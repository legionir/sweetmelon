import { Observable, Subject, fromEventPattern, timer, throwError, from } from 'rxjs';
import {
  retryWhen, delay, take, catchError,
  switchMap, filter, map, share
} from 'rxjs/operators';

declare const NativeSDK: any;

// ── Bridge Event as Observable ──

export function nativeEvent$<T = any>(eventName: string): Observable<T> {
  return fromEventPattern<T>(
    handler => NativeSDK.on(eventName, handler),
    (_, signal) => signal()
  ).pipe(share());
}

// ── Plugin Call as Observable ──

export function nativeCall$<T = any>(
  plugin: string,
  method: string,
  args?: Record<string, any>,
  options?: { timeout?: number; retry?: number; retryDelay?: number }
): Observable<T> {
  const opts = options || {};

  let obs = from(NativeSDK.call(plugin, method, args || {})) as Observable<T>;

  if (opts.retry && opts.retry > 0) {
    obs = obs.pipe(
      retryWhen(errors =>
        errors.pipe(
          delay(opts.retryDelay || 1000),
          take(opts.retry || 3),
        )
      )
    );
  }

  return obs;
}

// ── Connectivity Observable ──

export const connectivity$ = nativeEvent$<{
  online: boolean;
  primary: string;
  types: string[];
}>('connectivity.change').pipe(
  share()
);

export const isOnline$ = connectivity$.pipe(
  map(c => c.online),
  share()
);

// ── Geolocation Observable ──

export function watchPosition$(options?: { accuracy?: string }): Observable<any> {
  return new Observable(observer => {
    NativeSDK.geolocation.watchPosition(options || {});

    const posSub = NativeSDK.on('geolocation.position', (pos: any) => {
      observer.next(pos);
    });

    const errSub = NativeSDK.on('geolocation.error', (err: any) => {
      observer.error(new Error(err.message));
    });

    return () => {
      posSub();
      errSub();
      NativeSDK.geolocation.clearWatch();
    };
  });
}

// ── Sensor Observables ──

export function accelerometer$(intervalMs = 100): Observable<{x: number; y: number; z: number}> {
  return new Observable(observer => {
    NativeSDK.sensors.startAccelerometer({ intervalMs });

    const sub = NativeSDK.on('sensors.accelerometer', observer.next.bind(observer));

    return () => {
      sub();
      NativeSDK.sensors.stopAccelerometer();
    };
  });
}

export function gyroscope$(intervalMs = 100): Observable<{x: number; y: number; z: number}> {
  return new Observable(observer => {
    NativeSDK.sensors.startGyroscope({ intervalMs });
    const sub = NativeSDK.on('sensors.gyroscope', observer.next.bind(observer));
    return () => { sub(); NativeSDK.sensors.stopGyroscope(); };
  });
}

// ── Back Button Observable ──

export const backButton$ = nativeEvent$('backButton.pressed').pipe(share());

// ── App Lifecycle Observable ──

export const lifecycle$ = nativeEvent$<{
  state: 'resumed' | 'paused' | 'inactive' | 'detached';
  previousState: string;
}>('app.lifecycle.change').pipe(share());

export const onPause$ = lifecycle$.pipe(
  filter(e => e.state === 'paused' || e.state === 'inactive')
);

export const onResume$ = lifecycle$.pipe(
  filter(e => e.state === 'resumed')
);

// ── Keyboard Observable ──

export const keyboard$ = nativeEvent$<{
  visible: boolean;
  height: number;
}>('keyboard.change').pipe(share());

// ── Download Progress Observable ──

export function downloadWithProgress$(options: {
  url: string;
  fileName?: string;
  baseDir?: string;
}): Observable<{ type: 'progress'; percent: number } | { type: 'complete'; path: string }> {
  return new Observable(observer => {
    const taskId = `dl_${Date.now()}`;

    const progressSub = NativeSDK.on('download.progress', (data: any) => {
      if (data.taskId === taskId) {
        observer.next({ type: 'progress', percent: data.percent || 0 });
      }
    });

    const completeSub = NativeSDK.on('download.complete', (data: any) => {
      if (data.taskId === taskId) {
        observer.next({ type: 'complete', path: data.path });
        observer.complete();
      }
    });

    const errorSub = NativeSDK.on('download.error', (data: any) => {
      if (data.taskId === taskId) {
        observer.error(new Error(data.error));
      }
    });

    NativeSDK.downloadManager.download({ ...options, taskId });

    return () => {
      progressSub();
      completeSub();
      errorSub();
      NativeSDK.downloadManager.cancel(taskId);
    };
  });
}

// ── Poll Observable ──

export function pollPlugin$<T = any>(
  plugin: string,
  method: string,
  args?: Record<string, any>,
  intervalMs = 5000
): Observable<T> {
  return timer(0, intervalMs).pipe(
    switchMap(() => from(NativeSDK.call(plugin, method, args || {})) as Observable<T>)
  );
}
