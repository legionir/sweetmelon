# Text to Speech Plugin

Read text aloud using system TTS engine.

## Plugin Name
`textToSpeech`

## Methods

| Method | Args |
|--------|------|
| `speak` | `text, language?, rate?, pitch?, volume?` |
| `stop` | — |
| `pause` | — |
| `setLanguage` | `language` (e.g. `"en-US"`, `"fa-IR"`) |
| `setSpeechRate` | `rate` (0.0 - 2.0, default 0.5) |
| `setPitch` | `pitch` (0.5 - 2.0, default 1.0) |
| `setVolume` | `volume` (0.0 - 1.0) |
| `getLanguages` | List available languages |
| `getVoices` | List available voices |
| `isSpeaking` | — (returns `{ speaking }`) |
| `getInfo` | — (returns `{ name, version, speaking }`) |

## Events
- `tts.start`, `tts.complete`, `tts.cancel`, `tts.error`
- `tts.progress` — `{ text, start, end, word }`

## Usage
```javascript
await NativeSDK.textToSpeech.speak('سلام دنیا', { language: 'fa-IR', rate: 0.5 });

NativeSDK.on('tts.complete', () => {
  console.log('Finished speaking');
});
```
