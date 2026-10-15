# LLM Plugin

Chat with a GGUF language model on the device (llama.cpp through
[llamadart](https://pub.dev/packages/llamadart)). No server, no internet.

## Plugin Name
`llm`

Models come from the `modelManager` plugin (kind `llm`): the user imports a
`.gguf` (and, for images, its `mmproj` projector) from their own files.

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `load` | `modelId` or `path` (+ `mmproj`), load options below | `{ loaded, contextSize, backend, vision }` |
| `chat` | `text`, `images?`, `systemPrompt?`, `requestId?`, `params?` | `{ started, requestId }` — the answer streams as events |
| `stop` | — | `{ stopped }` |
| `reset` | `keepSystemPrompt?` | `{ reset }` |
| `setSystemPrompt` | `text` | `{ set }` |
| `getHistory` | — | `{ systemPrompt, messages }` |
| `countTokens` | `text` | `{ tokens }` |
| `unload` | — | `{ unloaded }` |
| `status` | — | `{ loaded, loading, generating, modelId, vision }` |

### Load options
`contextSize` (4096), `device` (`auto`/`cpu`/`gpu`), `gpuLayers`, `threads`,
`threadsBatch`, `batchSize`, `microBatchSize`, `flashAttention`
(`auto`/`on`/`off`), `useMmap`, `useMlock`, `kvCacheType`
(`f16`/`q8_0`/`q4_0`), `chatTemplate`, `ropeFrequencyBase`,
`ropeFrequencyScale`, `systemPrompt`, `maxContextTokens`.

### Generation params (`chat({ params })`)
`maxTokens` (1024), `temperature` (0.8), `topK` (40), `topP` (0.9), `minP` (0),
`repeatPenalty` (1.1), `presencePenalty` (0), `seed`, `stop` (list),
`enableThinking`, `thinkingBudget`, `streamBatchTokens` (1).

## Events
- `llm.token` — `{ requestId, text, thinking, index }`
- `llm.done` — `{ requestId, text, thinking, stopped, usage }`
- `llm.error` — `{ requestId, message }`
- `llm.state` — `{ state: loading|ready|error|unloaded }`

`chat` returns at once so a long answer never hits the bridge timeout. Only one
reply runs at a time (`reason: 'busy'`). Images need a model loaded with its
projector (`reason: 'no_vision'`) and must be inside the app's folders.

## Usage
```javascript
const { model } = await NativeSDK.modelManager.import({ kind: 'llm' });
await NativeSDK.llm.load({ modelId: model.id, contextSize: 4096 });

NativeSDK.on('llm.token', (e) => output.textContent += e.text);
NativeSDK.on('llm.done', (e) => console.log(e.usage));
await NativeSDK.llm.chat('Hello!', { params: { temperature: 0.7, topP: 0.9 } });
```
