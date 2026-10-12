# SIM Info Plugin

Read SIM card information.

## Plugin Name
`simInfo`

## Methods

| Method | Returns |
|--------|---------|
| `getSimInfo` | full SIM information |
| `getCarrierName` | `{ carrier: "MTN" }` |
| `getSimCount` | `{ count: 2 }` |
| `getInfo` | `{ name, version, platform }` |

**getSimInfo Returns:**
```json
{
  "available": true,
  "networkOperator": "MCI",
  "simOperator": "MCI",
  "simState": 5,
  "networkCountryIso": "ir",
  "simCountryIso": "ir",
  "simCount": 2
}
```

## Note
Requires `READ_PHONE_STATE` permission.

## Usage
```javascript
const carrier = await NativeSDK.simInfo.getCarrierName();
console.log('Carrier:', carrier.carrier);

const { count } = await NativeSDK.simInfo.getSimCount();
console.log('SIM cards:', count);

const info = await NativeSDK.simInfo.getSimInfo();
if (info.available) {
  document.getElementById('carrier').textContent = info.networkOperator;
  document.getElementById('country').textContent = info.simCountryIso.toUpperCase();
}
```
