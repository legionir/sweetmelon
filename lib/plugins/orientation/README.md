# Orientation Plugin

Lock and unlock screen orientation.

## Plugin Name
`orientation`

## Methods

### `lock`
| Param | Type | Default |
|-------|------|---------|
| `orientation` | `string` | `portrait` |

Values: `portrait`, `portraitUp`, `portraitDown`, `landscape`, `landscapeLeft`, `landscapeRight`

### `unlock`
Unlock to all orientations.

### `getInfo`

**Returns:** `{ name, version, supportedOrientations }`

## Usage
```javascript
await NativeSDK.orientation.lock('landscape');  // video player
await NativeSDK.orientation.unlock();           // back to normal
```
