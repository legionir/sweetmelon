# Loader Status Plugin

Internal plugin that exposes the state of the lazy plugin loader: which
plugins are loaded/unloaded, loader statistics, and manual
preload/unload/reload control.

## Plugin Name
`_loader`

## Methods

| Method | Description |
|--------|-------------|
| `getStats` | Loader-wide statistics |
| `getStatus` | Status of a single plugin |
| `preload` | Preload a list of plugins in the background |
| `unload` | Unload a loaded plugin |
| `reload` | Reload a plugin |
| `getLoadedPlugins` | List loaded plugin ids |
| `getUnloadedPlugins` | List registered-but-unloaded plugin ids |

### `getStatus`
| Param | Type |
|-------|------|
| `plugin` | `string` ✅ |

**Returns:** `{ plugin, registered, ...status }` — when the id is unknown, `{ plugin, registered: false }`.

### `preload`
| Param | Type |
|-------|------|
| `plugins` | `string[]` ✅ |

**Returns:** `{ preloading }` (the requested list; loading continues in the background).

### `unload` / `reload`
| Param | Type |
|-------|------|
| `plugin` | `string` ✅ |

**Returns:** `{ unloaded }` / `{ reloaded }`.

### `getLoadedPlugins` / `getUnloadedPlugins`
**Returns:** `{ plugins }`.

## Usage
```javascript
const stats = await NativeSDK._loader.getStats();
const { plugins: loaded } = await NativeSDK._loader.getLoadedPlugins();

// Warm up plugins the user is likely to need next
await NativeSDK._loader.preload(['camera', 'bluetooth']);

const status = await NativeSDK._loader.getStatus('camera');
console.log('camera:', status);

// Free a plugin that is no longer needed, bring it back later
await NativeSDK._loader.unload('bluetooth');
await NativeSDK._loader.reload('bluetooth');
```

## Notes
- The leading underscore marks this as an internal plugin; it is meant for diagnostics and tooling, not regular app features
- `getStats` returns the loader's own statistics map (counts, timings, etc.)
