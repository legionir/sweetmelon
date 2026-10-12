# Video Player Plugin

Play video from URL or local file (headless — audio only, no visual widget in WebView).

## Plugin Name
`videoPlayer`

## Methods

| Method | Args |
|--------|------|
| `create` | `url` or `path` (one required), `playerId?` (auto), `autoPlay?`, `looping?`, `volume?` (0-1) |
| `play` | `playerId` |
| `pause` | `playerId` |
| `seekTo` | `playerId, positionMs` |
| `setVolume` | `playerId, volume (0-1)` |
| `setPlaybackSpeed` | `playerId, speed (0.25-4.0)` |
| `setLooping` | `playerId, looping` |
| `getPosition` | `playerId` |
| `getDuration` | `playerId` |
| `getState` | `playerId` — full state object |
| `dispose` | `playerId` |
| `disposeAll` | — |
| `getInfo` | — (returns `{ name, version, activePlayers }`) |

## Events
### `videoPlayer.state`
```json
{ "playerId": "...", "isPlaying": true, "positionMs": 5000, "durationMs": 120000 }
```

## Usage
```javascript
const player = await NativeSDK.videoPlayer.create({
  url: 'https://example.com/video.mp4',
  autoPlay: true
});

// Control
await NativeSDK.videoPlayer.seekTo(player.playerId, 30000);
await NativeSDK.videoPlayer.setPlaybackSpeed(player.playerId, 1.5);

// Cleanup
await NativeSDK.videoPlayer.dispose(player.playerId);
```
