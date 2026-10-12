# In-App Purchase Plugin

Native in-app purchases and subscriptions.

## Plugin Name
`inAppPurchase`

## Methods

### `isAvailable`
**Returns:** `{ available: bool }`

### `getProducts`
| Param | Type | Required |
|-------|------|----------|
| `productIds` | `string[]` | ✅ |

**Returns:**
```json
{
  "products": [
    { "id": "premium_monthly", "title": "Premium Monthly", "price": "$4.99", "rawPrice": 4.99, "currencyCode": "USD" }
  ]
}
```

### `buyProduct` / `buySubscription`
| Param | Type | Required |
|-------|------|----------|
| `productId` | `string` | ✅ |

### `restorePurchases`

### `completePurchase`
Purchases are auto-completed via the purchase stream; this method exists for API compatibility.
**Returns:** `{ completed: true, note: "Auto-completed via stream" }`

### `getPurchaseHistory`
**Returns:** `{ note: "Use purchase events for history" }` — history is delivered through `purchase.*` events.

### `getInfo`

**Returns:** `{ name, version, available }`

## Events
| Event | Data |
|-------|------|
| `purchase.pending` | `{ productId, status }` |
| `purchase.completed` | `{ productId, purchaseId, transactionDate }` |
| `purchase.cancelled` | `{ productId }` |
| `purchase.error` | `{ productId, errorCode, errorMessage }` |

## Usage
```javascript
// Load products
const { available } = await NativeSDK.inAppPurchase.isAvailable();
if (!available) return;

const { products } = await NativeSDK.inAppPurchase.getProducts([
  'premium_monthly',
  'premium_yearly',
  'remove_ads'
]);

// Display products
products.forEach(p => {
  addProductCard(p.title, p.price, p.id);
});

// Handle purchase events FIRST
NativeSDK.on('purchase.completed', async (data) => {
  // Verify with your backend
  const valid = await verifyPurchase(data.productId, data.purchaseId);
  if (valid) {
    await unlockPremium();
    await NativeSDK.toast.show('Purchase successful! 🎉');
  }
});

NativeSDK.on('purchase.error', (data) => {
  NativeSDK.toast.show('Purchase failed: ' + data.errorMessage, { duration: 'long' });
});

// Buy
await NativeSDK.inAppPurchase.buySubscription('premium_monthly');

// Restore
await NativeSDK.inAppPurchase.restorePurchases();
```
