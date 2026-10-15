# Model Manager Plugin

Keeps AI models in one folder of the app and imports them from the user's own
files. The `llm` and `speechOffline` plugins read their models from here.

## Plugin Name
`modelManager`

## Layout
```
<app support dir>/models/<kind>/<id>/   the files of one model
```
`kind` groups models by use: `llm`, `stt`, `tts`... (lowercase letters, digits,
`_`). A model is a folder, because some are several files (a Whisper encoder,
decoder and tokens; a GGUF and its multimodal projector; a voice with its
`espeak-ng-data` folder).

## Methods

| Method | Args | Returns |
|--------|------|---------|
| `import` | `kind`, `name?`, `extensions?`, `extract?` (default `true`) | `{ imported, model }` or `{ imported: false, reason: 'cancelled' }` |
| `list` | `kind?` | `{ models }` |
| `get` | `id` | `{ found, model? }` |
| `rename` | `id`, `name` | `{ model }` |
| `remove` | `id` | `{ removed }` |
| `getInfo` | — | `{ root, count, sizeBytes }` |

`model` is `{ id, kind, name, dir, files: [{ name, path, size }], directories, sizeBytes, createdAt }`.

`import` opens the system file picker (several files allowed). The files, or an
archive (`.zip`, `.tar`, `.tar.gz`, `.tar.bz2`, `.tar.xz`), become one model.
Archives are unpacked and a single top-level folder is flattened. No permission
is needed. The picker copies each file into the app's cache, which is on the
same storage as the models folder, so the move is instant even for a
multi-gigabyte model.

## Events
- `modelManager.progress` — `{ id, stage: start|moving|extracting|done, file?, index?, files? }`

## Security
The plugins that run models accept only paths inside this folder (`..` and
links are resolved before the check).

## Usage
```javascript
const { model } = await NativeSDK.modelManager.import({ kind: 'llm' });
await NativeSDK.llm.load({ modelId: model.id });
```
