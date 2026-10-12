# Background Task Plugin

Schedule and run background tasks with custom actions.

## Plugin Name
`backgroundTask`

## Methods

### `register`
| Param | Type | Required |
|-------|------|----------|
| `taskId` | `string` | ✅ |
| `name` | `string` | — |
| `params` | `object` | — |

### `runOnce`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `taskId` | `string` | ✅ | — |
| `action` | `string` | — | `execute` |
| `params` | `object` | — | — |
| `timeoutMs` | `number` | — | `30000` |

**Actions:** `execute`, `httpSync`, `storageCleanup`, `cacheCleanup`, `compute`

### `startRepeating`
| Param | Type | Required | Default |
|-------|------|----------|---------|
| `taskId` | `string` | ✅ | — |
| `intervalMs` | `number` | ✅ (min 1000) | — |
| `action` | `string` | — | `execute` |
| `params` | `object` | — | — |
| `immediate` | `bool` | — | `true` |

### `stop` / `unregister` / `getTaskState` — `taskId` required
### `stopAll` / `getAllTasks`

### `getInfo`

**Returns:** `{ name, version, registeredTasks, runningTimers }`

## Events
| Event | Data |
|-------|------|
| `task.started` | `{ taskId, action, runCount }` |
| `task.completed` | `{ taskId, durationMs, result }` |
| `task.failed` | `{ taskId, error, durationMs }` |

## Usage
```javascript
// Register and run once
await NativeSDK.backgroundTask.register('sync_task', { name: 'Data Sync' });
const result = await NativeSDK.backgroundTask.runOnce('sync_task', {
  action: 'httpSync',
  params: { url: 'https://api.example.com/sync' }
});

// Repeating task (every 5 minutes)
await NativeSDK.backgroundTask.startRepeating('cleanup', 300000, {
  action: 'storageCleanup',
  params: { olderThanDays: 7 }
});

// Listen
NativeSDK.on('task.completed', (data) => {
  console.log('Task done:', data.taskId, data.durationMs + 'ms');
});

// Stop
await NativeSDK.backgroundTask.stop('cleanup');
await NativeSDK.backgroundTask.stopAll();
```
