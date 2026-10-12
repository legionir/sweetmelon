# SMS OTP Plugin

Auto-read SMS OTP codes (Android only).

## Plugin Name
`smsOtp`

## Methods

| Method | Returns |
|--------|---------|
| `getAppSignature` | `{ signature: "abc123" }` |
| `startListening` | `{ listening: true }` |
| `stopListening` | `{ listening: false }` |
| `getLastCode` | `{ code: "123456" }` |
| `requestHint` | `{ hint: "+98912***789" }` |
| `getInfo` | `{ name, version, listening, signature, lastCode }` |

## Events
### `smsOtp.received`
```json
{ "code": "123456", "timestamp": "..." }
```

## SMS Format Required
```
Your verification code is 123456
FA+9876543210       ← app signature from getAppSignature
```

## Usage
```javascript
const { signature } = await NativeSDK.smsOtp.getAppSignature();
// Send signature to your backend to include in SMS

await NativeSDK.smsOtp.startListening();
NativeSDK.on('smsOtp.received', (data) => {
  otpInput.value = data.code;
  verifyOtp(data.code);
});
```
