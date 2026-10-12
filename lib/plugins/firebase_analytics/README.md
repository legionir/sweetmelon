# Firebase Analytics Plugin

Track events and user behavior with Firebase Analytics.

## Plugin Name
`firebaseAnalytics`

## Methods

### `logEvent`
| Param | Type | Required |
|-------|------|----------|
| `name` | `string` | ✅ |
| `parameters` | `object` | — |

### Predefined Events
| Method | Parameters |
|--------|-----------|
| `setCurrentScreen` | `screenName`, `screenClass` |
| `setUserId` | `id` |
| `setUserProperty` | `name`, `value` |
| `logLogin` | `method` |
| `logSignUp` | `method` |
| `logSearch` | `searchTerm` |
| `logPurchase` | `currency`, `value`, `transactionId`, `items` |
| `logViewItem` | `currency`, `value`, `items` |
| `logAddToCart` | `currency`, `value`, `items` |
| `logBeginCheckout` | `currency`, `value`, `items` |
| `logShare` | `contentType`, `itemId`, `method` |
| `logSelectContent` | `contentType` ✅, `itemId` ✅ |
| `logViewItemList` | `itemListId`, `itemListName`, `items` |
| `logTutorialBegin` | — |
| `logTutorialComplete` | — |
| `logLevelStart` | `levelName` |
| `logLevelEnd` | `levelName`, `success` |

### `setAnalyticsCollectionEnabled` — `enabled` (bool ✅)
### `resetAnalyticsData` / `getAppInstanceId`

### `getInfo`

**Returns:** `{ name, version, enabled, initialized }`

## Usage
```javascript
// Screen tracking (Angular example)
router.events.subscribe(event => {
  NativeSDK.firebaseAnalytics.setCurrentScreen(event.url, 'WebView');
});

// User identification
await NativeSDK.firebaseAnalytics.setUserId(user.id);
await NativeSDK.firebaseAnalytics.setUserProperty('plan', 'premium');

// Custom events
await NativeSDK.firebaseAnalytics.logEvent('tutorial_complete', {
  tutorial_id: 'onboarding_v2',
  duration_seconds: 45
});

// E-commerce
await NativeSDK.firebaseAnalytics.logPurchase({
  currency: 'USD',
  value: 49.99,
  transactionId: 'txn_' + Date.now(),
  items: [{
    itemId: 'premium_plan',
    itemName: 'Premium Plan',
    price: 49.99,
    quantity: 1
  }]
});
```
