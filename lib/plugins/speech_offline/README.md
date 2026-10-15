# Speech Offline Plugin

Speech recognition and speech synthesis on the device
([sherpa-onnx](https://pub.dev/packages/sherpa_onnx)). They run in a worker
isolate, so they never block other calls.

## Plugin Name
`speechOffline`

Models come from the `modelManager` plugin: kind `stt` for recognition, `tts`
for voices. The user imports them from their own files (the sherpa-onnx
releases ship them as `.tar.bz2`, which `modelManager` unpacks).

| Model | Files |
|-------|-------|
| Whisper | `*-encoder.onnx`, `*-decoder.onnx`, `*-tokens.txt` (quantised `int8` files are preferred) |
| Transducer | `encoder`, `decoder`, `joiner` `.onnx` + `tokens.txt` |
| SenseVoice / Paraformer | one `.onnx` + `tokens.txt` (name the type: they look alike) |
| Piper / VITS voice | `.onnx`, `tokens.txt`, the `espeak-ng-data` folder (`lexicon.txt` if present) |
| Kokoro voice | `.onnx`, `voices.bin`, `tokens.txt`, `espeak-ng-data` |

## Recognition

| Method | Args | Returns |
|--------|------|---------|
| `loadRecognizer` | `modelId`, `type?` (`auto`/`whisper`/`transducer`/`sense_voice`/`paraformer`), `language?`, `task?` (`transcribe`/`translate`), `threads?`, `tailPaddings?`, `decodingMethod?`, `useItn?` | `{ loaded, type }` |
| `startListening` | `sampleRate?` (16000), `maxSeconds?` (60) | `{ started }` or `{ started: false, reason }` |
| `stopListening` | `recognize?` (`true`) | `{ text, audioSeconds, decodeMs }` |
| `cancelListening` | — | `{ cancelled }` |
| `transcribeFile` | `path` (a WAV inside the app's folders) | `{ text }` |
| `unloadRecognizer` | — | `{ unloaded }` |

Hold-to-talk: `startListening` when the button goes down, `stopListening` when
it is released. The microphone permission is asked by `startListening`, the
first time (`reason: 'permission_denied'` if refused). Whisper reads 30 s at a
time; longer speech is cut into 28 s windows.

## Synthesis

| Method | Args | Returns |
|--------|------|---------|
| `loadSynthesizer` | `modelId`, `type?` (`auto`/`vits`/`kokoro`), `threads?`, `noiseScale?`, `noiseScaleW?`, `lengthScale?`, `silenceScale?`, `maxNumSentences?`, `lang?` | `{ loaded, sampleRate, speakers }` |
| `speak` | `text`, `id?`, `speed?` (1.0), `speakerId?` (0), `silenceScale?`, `volume?`, `rate?` (1.0, 0.5-2) | `{ queued, id }` |
| `synthesize` | `text`, `speed?`, `speakerId?`, `silenceScale?` | `{ path, sampleRate, durationMs, synthMs }` |
| `stopSpeaking` | — | `{ stopped }` |
| `setVolume` | `volume` (0-1) | `{ volume }` |
| `unloadSynthesizer` | — | `{ unloaded }` |
| `status` | — | `{ recognizer, synthesizer }` |

`speed` is the model's own speaking speed (the pitch stays). The models have no
pitch control; `rate` is the playback rate, which changes speed *and* pitch.
To change only the pitch by a factor `p`, play at `rate: p` and synthesise at
`speed: wanted / p`.

`speak` queues the text and synthesises it at once, while the previous text is
still playing, so sentences follow each other without a gap. Feed it one
sentence at a time. `noiseScale`, `noiseScaleW` and `lengthScale` are fixed when
the voice is loaded; `speed`, `speakerId` and `silenceScale` change per call.

## Events
- `speechOffline.listening` — `{ listening }`
- `speechOffline.level` — `{ level }` 0..1, about 12 times a second while recording
- `speechOffline.transcribing`, `speechOffline.result`
- `speechOffline.speak` — `{ id, state: started|finished|error|idle }`
- `speechOffline.state` — `{ part: recognizer|synthesizer, state: loading|ready|error|unloaded }`
- `speechOffline.error`, `speechOffline.limit`

## Usage
```javascript
await NativeSDK.speechOffline.loadRecognizer({ modelId: stt.id, language: 'fa' });
await NativeSDK.speechOffline.loadSynthesizer({ modelId: tts.id });

await NativeSDK.speechOffline.startListening();
// ... the user speaks, releases the button ...
const { text } = await NativeSDK.speechOffline.stopListening();
await NativeSDK.speechOffline.speak(text, { speed: 1.1 });
```
