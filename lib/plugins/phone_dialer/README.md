# Phone Dialer Plugin

Make calls, send SMS, send email.

## Plugin Name
`phoneDialer`

## Methods

| Method | Args |
|--------|------|
| `dial` | `number` — opens dialer |
| `directCall` | `number` — starts call |
| `canDial` | `number` |
| `sendSms` | `number, body?` |
| `sendEmail` | `to, subject?, body?, cc?, bcc?` |
| `getInfo` | — (returns `{ name, version, supportedSchemes }`) |

## Usage
```javascript
await NativeSDK.phoneDialer.dial('+989123456789');
await NativeSDK.phoneDialer.sendSms('+989123456789', 'Hello!');
await NativeSDK.phoneDialer.sendEmail({
  to: 'support@app.com',
  subject: 'Bug Report',
  body: 'I found a bug...'
});
```
