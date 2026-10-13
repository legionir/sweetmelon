# NativeResilience

`js/native-resilience.js` adds retries, circuit breakers and an offline queue on top of `NativeSDK`. Include it after `native-sdk.js`:

```html
<script src="js/native-sdk.js"></script>
<script src="js/native-resilience.js"></script>
```

## API

| Member | Description |
| --- | --- |
| `NativeResilience.init(config?)` | Optional configuration: `{ retry, circuitBreaker, offlineQueue }` |
| `NativeResilience.resilientCall(plugin, method, args, options)` | A call with retry and circuit breaker; options: `retry`, `circuitBreaker` (both on by default), `queueIfOffline` |
| `NativeResilience.RetryManager` | Retries with exponential backoff (defaults: `maxRetries: 3`, `backoffMultiplier: 2`) |
| `NativeResilience.CircuitBreaker` | One breaker per plugin; opens after repeated failures (defaults: `failureThreshold: 5`, `resetTimeoutMs: 30000`) |
| `NativeResilience.OfflineQueue` | Queues calls while the device is offline and replays them when it is back |
| `NativeResilience.getStats()` | Breaker states, queue size and retry configuration |

```javascript
NativeResilience.init({ retry: { maxRetries: 5 } });

const result = await NativeResilience.resilientCall(
  'http', 'post', { url, body },
  { queueIfOffline: true },
);
```
