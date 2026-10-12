# Angular Integration Guide

## ۱) Build Angular
```bash
ng build --configuration production \
  --output-path /path/to/flutter/assets/www \
  --base-href ./
```

## ۲) اضافه کردن Bridge SDK

فایل `native-sdk.js` را در `angular.json` اضافه کنید:

```json
"scripts": [
  "src/assets/native-sdk.js"
]
```

یا در `index.html`:

```html
<script src="assets/native-sdk.js"></script>
```

## ۳) سرویس Angular

فایل `src/app/services/native-bridge.service.ts`:

```typescript
import { Injectable, NgZone } from '@angular/core';

declare const NativeSDK: any;

@Injectable({ providedIn: 'root' })
export class NativeBridgeService {
  private ready = false;

  constructor(private zone: NgZone) {}

  async init(): Promise<void> {
    if (this.ready) return;
    await NativeSDK.waitForReady(10000);
    this.ready = true;
  }

  async call<T = any>(plugin: string, method: string, args?: any): Promise<T> {
    await this.init();
    return NativeSDK.call(plugin, method, args || {});
  }

  on(event: string, callback: (data: any) => void): () => void {
    return NativeSDK.on(event, (data: any) => {
      this.zone.run(() => callback(data));
    });
  }

  // Shortcut methods

  get storage() { return NativeSDK.storage; }
  get secureStorage() { return NativeSDK.secureStorage; }
  get http() { return NativeSDK.http; }
  get deviceInfo() { return NativeSDK.deviceInfo; }
  get permission() { return NativeSDK.permission; }
  get connectivity() { return NativeSDK.connectivity; }
  get clipboard() { return NativeSDK.clipboard; }
  get share() { return NativeSDK.share; }
  get notification() { return NativeSDK.notification; }
  get statusBar() { return NativeSDK.statusBar; }
  get orientation() { return NativeSDK.orientation; }
  get haptic() { return NativeSDK.haptic; }
  get keyboard() { return NativeSDK.keyboard; }
  get backButton() { return NativeSDK.backButton; }
  get intent() { return NativeSDK.intent; }
  get fileSystem() { return NativeSDK.fileSystem; }
  get camera() { return NativeSDK.camera; }
  get geolocation() { return NativeSDK.geolocation; }
  get appLifecycle() { return NativeSDK.appLifecycle; }
}
```

## ۴) استفاده در Component

```typescript
import { Component, OnInit, OnDestroy } from '@angular/core';
import { NativeBridgeService } from './services/native-bridge.service';

@Component({
  selector: 'app-root',
  template: `
    <div>
      <p>Online: {{ isOnline }}</p>
      <p>Device: {{ deviceModel }}</p>
      <button (click)="saveData()">Save</button>
      <button (click)="loadData()">Load</button>
    </div>
  `
})
export class AppComponent implements OnInit, OnDestroy {
  isOnline = true;
  deviceModel = '';

  private unsubConnectivity?: () => void;
  private unsubBack?: () => void;

  constructor(private native: NativeBridgeService) {}

  async ngOnInit() {
    // Device info
    const info = await this.native.deviceInfo.getAll();
    this.deviceModel = info.device?.model || 'Unknown';

    // Connectivity watch
    this.unsubConnectivity = this.native.on('connectivity.change', (data) => {
      this.isOnline = data.online;
    });

    // Back button
    await this.native.backButton.enableIntercept();
    this.unsubBack = this.native.on('backButton.pressed', () => {
      // handle back in Angular router
      window.history.back();
    });
  }

  async saveData() {
    await this.native.storage.set('user', { name: 'Ali', role: 'admin' });
    await this.native.haptic.lightImpact();
  }

  async loadData() {
    const data = await this.native.storage.get('user');
    console.log('Loaded:', data);
  }

  ngOnDestroy() {
    this.unsubConnectivity?.();
    this.unsubBack?.();
  }
}
```

## ۵) Routing + Back Button

در `app.module.ts`:

```typescript
import { APP_INITIALIZER } from '@angular/core';

export function initBridge(native: NativeBridgeService) {
  return () => native.init();
}

@NgModule({
  providers: [
    {
      provide: APP_INITIALIZER,
      useFactory: initBridge,
      deps: [NativeBridgeService],
      multi: true
    }
  ]
})
export class AppModule {}
```

## ۶) نکات مهم

- **base-href**: حتما `./` باشد
- **SPA routing**: AssetServer از fallback به `index.html` پشتیبانی می‌کند
- **Zone.js**: eventهای bridge خارج از Angular zone هستند، باید با `NgZone.run` برگردانید
- **Type Safety**: فایل `native-sdk.d.ts` را در `src/typings.d.ts` import کنید
