# Events Reference

All events that can be listened to via `NativeSDK.on()`.

## How to use

```javascript
// Subscribe
const unsubscribe = NativeSDK.on('event.name', (data) => {
  console.log(data);
});

// Unsubscribe
unsubscribe();
```

## All Events

### App & System

| Event | Plugin | Data | Description |
|-------|--------|------|-------------|
| `app.lifecycle.change` | appLifecycle | `{ state, previousState }` | App state changed |
| `connectivity.change` | connectivity | `{ online, primary, types }` | Network changed |
| `keyboard.change` | keyboard | `{ visible, height }` | Keyboard show/hide |
| `backButton.pressed` | backButton | `{ intercepted }` | Back button pressed |

### Location

| Event | Plugin | Data | Description |
|-------|--------|------|-------------|
| `geolocation.position` | geolocation | Position object | Position update |
| `geolocation.error` | geolocation | `{ message }` | Location error |
| `bgGeo.position` | backgroundGeolocation | Position object | Background position |

### Media

| Event | Plugin | Data | Description |
|-------|--------|------|-------------|
| `audio.playerState` | audio | `{ state, isPlaying }` | Audio state |
| `audio.position` | audio | `{ positionMs }` | Playback position |
| `cameraPreview.photoTaken` | cameraPreview | `{ path, size }` | Photo captured |
| `qrScanner.scanned` | qrScanner | `{ value, format }` | QR/barcode scanned |

### Notifications

| Event | Plugin | Data | Description |
|-------|--------|------|-------------|
| `notification.tap` | notification | `{ id, payload }` | Notification tapped |
| `push.received` | pushNotification | `{ title, body, data }` | Push received |
| `push.tap` | pushNotification | `{ title, body, data }` | Push tapped |
| `push.tokenRefreshed` | pushNotification | `{ token }` | FCM token changed |

### Hardware

| Event | Plugin | Data | Description |
|-------|--------|------|-------------|
| `bluetooth.deviceFound` | bluetooth | `{ deviceId, name, rssi }` | BLE device found |
| `nfc.tagDiscovered` | nfc | `{ id, type, records }` | NFC tag read |
| `sensors.accelerometer` | sensors | `{ x, y, z }` | Accelerometer data |
| `sensors.gyroscope` | sensors | `{ x, y, z }` | Gyroscope data |
| `shake.detected` | shakeDetection | `{ magnitude, count }` | Device shaken |
| `volume.pressed` | volumeButtons | `{ direction }` | Volume button |
| `pedometer.step` | pedometer | `{ steps }` | Step counted |
| `alarm.fired` | alarm | `{ alarmId, title }` | Alarm triggered |

### Network

| Event | Plugin | Data | Description |
|-------|--------|------|-------------|
| `websocket.message` | websocket | `{ id, data, type }` | WS message |
| `websocket.connected` | websocket | `{ id, url }` | WS connected |
| `websocket.disconnected` | websocket | `{ id, closeCode }` | WS disconnected |
| `download.progress` | downloadManager | `{ taskId, percent }` | Download progress |
| `download.complete` | downloadManager | `{ taskId, path }` | Download done |

### Auth & Purchase

| Event | Plugin | Data | Description |
|-------|--------|------|-------------|
| `auth.stateChanged` | firebaseAuth | `{ user, signedIn }` | Auth state |
| `socialLogin.signedIn` | socialLogin | `{ provider, user }` | Social login |
| `purchase.completed` | inAppPurchase | `{ productId }` | Purchase done |
| `purchase.error` | inAppPurchase | `{ errorMessage }` | Purchase failed |

### Updates

| Event | Plugin | Data | Description |
|-------|--------|------|-------------|
| `update.available` | liveUpdater | `{ version, size }` | Update found |
| `update.downloadProgress` | liveUpdater | `{ percent }` | Downloading |
| `update.applied` | liveUpdater | `{ newVersion }` | Update applied |
| `update.rolledBack` | liveUpdater | `{ version }` | Rolled back |

### Tasks

| Event | Plugin | Data | Description |
|-------|--------|------|-------------|
| `task.started` | backgroundTask | `{ taskId }` | Task started |
| `task.completed` | backgroundTask | `{ taskId, result }` | Task done |
| `task.failed` | backgroundTask | `{ taskId, error }` | Task failed |
