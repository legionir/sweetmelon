# Social Login Plugin

Authenticate with Google and Phone (SMS).

## Plugin Name
`socialLogin`

## Methods

### `signInWithGoogle`
**Returns:**
```json
{ "success": true, "user": { "uid": "...", "email": "...", "displayName": "..." }, "isNewUser": false }
```

### `signInWithPhone`
| Param | Type | Required |
|-------|------|----------|
| `phoneNumber` | `string` | ✅ (E.164 format) |

**Returns:** `{ success: true, codeSent: true, verificationId: "..." }`

### `verifyPhoneCode`
| Param | Type | Required |
|-------|------|----------|
| `code` | `string` | ✅ |
| `verificationId` | `string` | — |

### `signInAnonymously` / `signOut`
### `linkWithGoogle` — Link Google to existing account
### `linkWithPhone` — Phone sign-in/link flow; `phoneNumber` required (E.164), same flow and result as `signInWithPhone`
### `getCurrentUser` / `isSignedIn` / `getProviders`

### `getInfo`

**Returns:** `{ name, version }`

## Events
| Event | Data |
|-------|------|
| `socialLogin.signedIn` | `{ provider, user }` |
| `socialLogin.signedOut` | — |

## Usage
```javascript
// Google Sign In
const { success, user, isNewUser } = await NativeSDK.socialLogin.signInWithGoogle();
if (success) {
  if (isNewUser) await createProfile(user);
  router.navigate('/home');
}

// Phone Auth
const step1 = await NativeSDK.socialLogin.signInWithPhone('+989123456789');
if (step1.codeSent) {
  const code = await showOtpDialog();
  const result = await NativeSDK.socialLogin.verifyPhoneCode(code, step1.verificationId);
  if (result.success) router.navigate('/home');
}

// Check current user
const { signedIn, user } = await NativeSDK.socialLogin.getCurrentUser();
if (!signedIn) router.navigate('/login');

// Sign out
await NativeSDK.socialLogin.signOut();
```
