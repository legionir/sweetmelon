# Contacts Plugin

Read device contacts.

## Plugin Name
`contacts`

## Methods

| Method | Args |
|--------|------|
| `getAll` | `limit?, offset?, withPhoto?, withProperties?` |
| `getById` | `id` |
| `search` | `query` |
| `getCount` | — |
| `pickContact` | Opens native contact picker |
| `getInfo` | — (returns `{ name, version }`) |

## Contact Object
```json
{
  "id": "123",
  "displayName": "Ali Ahmadi",
  "name": { "first": "Ali", "last": "Ahmadi" },
  "phones": [{ "number": "+989123456789", "label": "mobile" }],
  "emails": [{ "address": "ali@test.com", "label": "work" }]
}
```

## Usage
```javascript
const { contacts } = await NativeSDK.contacts.search('Ali');
const picked = await NativeSDK.contacts.pickContact();
```
