---
layout: home

hero:
  name: "Sweetmelon"
  text: "Flutter Native Bridge"
  tagline: Run Angular, React, or Vue apps inside Flutter with 104 native plugins
  image:
    src: /logo.svg
    alt: Sweetmelon
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: View Plugins
      link: /plugins/overview
    - theme: alt
      text: GitHub
      link: https://github.com/your-org/sweetmelon

features:
  - icon: 🔌
    title: 104 Native Plugins
    details: Camera, GPS, Bluetooth, NFC, Biometrics, Database, Push Notifications, In-App Purchase, and 83 more.
    link: /plugins/overview
    linkText: Browse all plugins

  - icon: ⚡
    title: Zero Latency Bridge
    details: Optimized JSON protocol with batch calls, caching, rate limiting, and circuit breaker.
    link: /advanced/performance

  - icon: 🔒
    title: Security Built-in
    details: Bridge authentication, message signing, SSL pinning, anti-tampering, and encrypted storage.
    link: /advanced/security

  - icon: 📦
    title: Framework Agnostic
    details: Works with Angular, React, Vue, Svelte, or vanilla HTML/JS. Full TypeScript support.
    link: /guide/frameworks/angular

  - icon: 🚀
    title: Live Updates
    details: Deploy HTML/JS changes instantly without Play Store review. Auto-rollback on failures.
    link: /plugins/advanced/live-updater

  - icon: 🔥
    title: Firebase Ready
    details: Analytics, Crashlytics, FCM Push, Remote Config, and Auth — all accessible from JavaScript.
    link: /plugins/firebase/analytics
---

<style>
:root {
  --vp-home-hero-name-color: transparent;
  --vp-home-hero-name-background: linear-gradient(135deg, #6C63FF 10%, #03DAC6 100%);
}
</style>

## Quick Example

```javascript
// Wait for bridge
await NativeSDK.waitForReady();

// Take a photo
const photo = await NativeSDK.camera.takePhoto({ quality: 90 });

// Save to secure storage
await NativeSDK.secureStorage.set('last_photo', photo.path);

// Show toast
await NativeSDK.toast.show('Photo saved! 📸');

// Listen to connectivity
NativeSDK.on('connectivity.change', (data) => {
  console.log('Online:', data.online);
});
```

## Trusted Architecture

```
┌─────────────────────────────────────┐
│     Your HTML/JS/CSS App            │
│  (Angular, React, Vue, vanilla)     │
├─────────────────────────────────────┤
│         NativeSDK (JS)              │
├─────────────────────────────────────┤
│      Message Bridge (Dart)          │
├─────────────────────────────────────┤
│   Security │ Cache │ Rate Limit     │
├─────────────────────────────────────┤
│     104 Native Plugin Registry       │
├─────────────────────────────────────┤
│     Android / iOS Native APIs       │
└─────────────────────────────────────┘
```
