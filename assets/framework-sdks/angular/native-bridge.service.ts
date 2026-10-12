import { Injectable, NgZone, OnDestroy } from '@angular/core';
import { Observable, Subject, fromEventPattern } from 'rxjs';
import { filter, map, share } from 'rxjs/operators';

// Type declarations
declare global {
  interface Window {
    NativeSDK: any;
  }
}

export interface PluginCallOptions {
  timeout?: number;
  retry?: boolean;
  maxRetries?: number;
}

export interface NativeEvent<T = any> {
  event: string;
  data: T;
  timestamp: Date;
}

@Injectable({ providedIn: 'root' })
export class NativeBridgeService implements OnDestroy {
  private _ready = false;
  private _readyPromise: Promise<void> | null = null;
  private _eventSubject = new Subject<NativeEvent>();
  private _unsubscribers: Array<() => void> = [];

  constructor(private zone: NgZone) {}

  // ── Core ──

  async initialize(timeoutMs = 10000): Promise<void> {
    if (this._ready) return;
    if (this._readyPromise) return this._readyPromise;

    this._readyPromise = new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('Bridge initialization timeout'));
      }, timeoutMs);

      window.NativeSDK.waitForReady(timeoutMs)
        .then(() => {
          clearTimeout(timeout);
          this._ready = true;
          this._setupGlobalEventForwarding();
          resolve();
        })
        .catch(reject);
    });

    return this._readyPromise;
  }

  async call<T = any>(
    plugin: string,
    method: string,
    args?: Record<string, any>,
    options?: PluginCallOptions
  ): Promise<T> {
    await this.initialize();
    return this.zone.runOutsideAngular(() =>
      window.NativeSDK.call(plugin, method, args || {}, options)
    ).then(result => this.zone.run(() => result));
  }

  // ── Events as Observables ──

  events<T = any>(eventName: string): Observable<T> {
    return this._eventSubject.asObservable().pipe(
      filter(e => e.event === eventName),
      map(e => e.data as T),
      share()
    );
  }

  allEvents(): Observable<NativeEvent> {
    return this._eventSubject.asObservable();
  }

  private _setupGlobalEventForwarding(): void {
    const allEventNames = [
      'app.lifecycle.change', 'connectivity.change', 'connectivity.error',
      'intent.deepLink', 'intent.error', 'geolocation.position',
      'geolocation.error', 'backButton.pressed', 'notification.tap',
      'keyboard.change', 'qrScanner.scanned', 'audio.playerState',
      'audio.position', 'smsOtp.received', 'download.progress',
      'download.complete', 'download.error', 'bluetooth.deviceFound',
      'bluetooth.connectionState', 'nfc.tagDiscovered', 'nfc.error',
      'speechToText.result', 'speechToText.status', 'speechToText.error',
      'tts.start', 'tts.complete', 'tts.cancel', 'tts.error',
      'tts.progress', 'videoPlayer.state', 'inAppBrowser.loadStop',
      'inAppBrowser.error', 'foregroundService.started',
      'foregroundService.stopped', 'bgGeo.position', 'bgGeo.error',
      'alarm.fired', 'pedometer.step', 'pedometer.status',
      'shake.detected', 'volume.pressed', 'sensors.accelerometer',
      'sensors.gyroscope', 'sensors.magnetometer',
      'push.registered', 'push.received', 'push.tap',
      'appUpdate.available', 'textZoom.changed',
      'shareTarget.received', 'websocket.connected',
      'websocket.message', 'websocket.disconnected', 'websocket.error',
      'task.started', 'task.completed', 'task.failed',
    ];

    allEventNames.forEach(eventName => {
      const unsub = window.NativeSDK.on(eventName, (data: any) => {
        this.zone.run(() => {
          this._eventSubject.next({
            event: eventName,
            data,
            timestamp: new Date()
          });
        });
      });
      this._unsubscribers.push(unsub);
    });
  }

  // ── Plugin Shortcuts ──

  get permission() { return window.NativeSDK.permission; }
  get appLifecycle() { return window.NativeSDK.appLifecycle; }
  get deviceInfo() { return window.NativeSDK.deviceInfo; }
  get connectivity() { return window.NativeSDK.connectivity; }
  get storage() { return window.NativeSDK.storage; }
  get fileSystem() { return window.NativeSDK.fileSystem; }
  get http() { return window.NativeSDK.http; }
  get intent() { return window.NativeSDK.intent; }
  get clipboard() { return window.NativeSDK.clipboard; }
  get share() { return window.NativeSDK.share; }
  get camera() { return window.NativeSDK.camera; }
  get geolocation() { return window.NativeSDK.geolocation; }
  get backButton() { return window.NativeSDK.backButton; }
  get secureStorage() { return window.NativeSDK.secureStorage; }
  get notification() { return window.NativeSDK.notification; }
  get statusBar() { return window.NativeSDK.statusBar; }
  get orientation() { return window.NativeSDK.orientation; }
  get haptic() { return window.NativeSDK.haptic; }
  get keyboard() { return window.NativeSDK.keyboard; }
  get biometrics() { return window.NativeSDK.biometrics; }
  get qrScanner() { return window.NativeSDK.qrScanner; }
  get audio() { return window.NativeSDK.audio; }
  get smsOtp() { return window.NativeSDK.smsOtp; }
  get downloadManager() { return window.NativeSDK.downloadManager; }
  get database() { return window.NativeSDK.database; }
  get contacts() { return window.NativeSDK.contacts; }
  get phoneDialer() { return window.NativeSDK.phoneDialer; }
  get bluetooth() { return window.NativeSDK.bluetooth; }
  get nfc() { return window.NativeSDK.nfc; }
  get speechToText() { return window.NativeSDK.speechToText; }
  get textToSpeech() { return window.NativeSDK.textToSpeech; }
  get videoPlayer() { return window.NativeSDK.videoPlayer; }
  get inAppBrowser() { return window.NativeSDK.inAppBrowser; }
  get pdf() { return window.NativeSDK.pdf; }
  get encryption() { return window.NativeSDK.encryption; }
  get websocket() { return window.NativeSDK.websocket; }
  get backgroundTask() { return window.NativeSDK.backgroundTask; }
  get dialog() { return window.NativeSDK.dialog; }
  get toast() { return window.NativeSDK.toast; }
  get splashScreen() { return window.NativeSDK.splashScreen; }
  get pushNotification() { return window.NativeSDK.pushNotification; }
  get wakeLock() { return window.NativeSDK.wakeLock; }
  get cookieManager() { return window.NativeSDK.cookieManager; }
  get cacheControl() { return window.NativeSDK.cacheControl; }
  get appUpdate() { return window.NativeSDK.appUpdate; }
  get filePicker() { return window.NativeSDK.filePicker; }
  get fileOpener() { return window.NativeSDK.fileOpener; }
  get sensors() { return window.NativeSDK.sensors; }
  get screenBrightness() { return window.NativeSDK.screenBrightness; }
  get flashlight() { return window.NativeSDK.flashlight; }
  get navigationBar() { return window.NativeSDK.navigationBar; }
  get privacyScreen() { return window.NativeSDK.privacyScreen; }
  get nativeSettings() { return window.NativeSDK.nativeSettings; }
  get calendar() { return window.NativeSDK.calendar; }
  get badge() { return window.NativeSDK.badge; }
  get foregroundService() { return window.NativeSDK.foregroundService; }
  get backgroundGeolocation() { return window.NativeSDK.backgroundGeolocation; }
  get mediaManager() { return window.NativeSDK.mediaManager; }
  get fileCompressor() { return window.NativeSDK.fileCompressor; }
  get zip() { return window.NativeSDK.zip; }
  get shareTarget() { return window.NativeSDK.shareTarget; }
  get inAppReview() { return window.NativeSDK.inAppReview; }
  get nativeMarket() { return window.NativeSDK.nativeMarket; }
  get screenshot() { return window.NativeSDK.screenshot; }
  get safeArea() { return window.NativeSDK.safeArea; }
  get datePicker() { return window.NativeSDK.datePicker; }
  get actionSheet() { return window.NativeSDK.actionSheet; }
  get textZoom() { return window.NativeSDK.textZoom; }
  get accessibility() { return window.NativeSDK.accessibility; }
  get alarm() { return window.NativeSDK.alarm; }
  get pedometer() { return window.NativeSDK.pedometer; }
  get shakeDetection() { return window.NativeSDK.shakeDetection; }
  get volumeButtons() { return window.NativeSDK.volumeButtons; }
  get emailComposer() { return window.NativeSDK.emailComposer; }

  ngOnDestroy(): void {
    this._unsubscribers.forEach(fn => fn());
    this._eventSubject.complete();
  }
}
