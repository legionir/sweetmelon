# Google Maps Plugin

Geocoding, directions, and places search.

## Plugin Name
`googleMaps`

## Setup
```javascript
await NativeSDK.googleMaps.configure({ apiKey: 'YOUR_GOOGLE_MAPS_API_KEY' });
```

## Methods

### `configure`
| Param | Type | Required |
|-------|------|----------|
| `apiKey` | `string` | ✅ |

Sets the Google Maps/Places API key used by `getDirections`, `searchPlaces` and `getPlaceDetails`. Returns `{ configured }`.

### `geocode`
| Param | Type | Required |
|-------|------|----------|
| `address` | `string` | ✅ |

**Returns:** `{ found, latitude, longitude, formattedAddress, placeId }`

### `reverseGeocode`
| Param | Type | Required |
|-------|------|----------|
| `latitude` | `number` | ✅ |
| `longitude` | `number` | ✅ |

**Returns:** `{ found, formattedAddress, components }`

### `getDirections`
| Param | Type | Default |
|-------|------|---------|
| `origin` | `string` | ✅ |
| `destination` | `string` | ✅ |
| `mode` | `string` | `"driving"` |

**mode:** `driving`, `walking`, `bicycling`, `transit`

### `searchPlaces`
| Param | Type | Required |
|-------|------|----------|
| `query` | `string` | ✅ |
| `latitude` | `number` | — |
| `longitude` | `number` | — |
| `radius` | `number` | `5000` |

### `getPlaceDetails`
| Param | Type | Required |
|-------|------|----------|
| `placeId` | `string` | ✅ |

### `calculateDistance` — Haversine formula (no API call)
| Param | Type | Required |
|-------|------|----------|
| `lat1` | `number` | ✅ |
| `lng1` | `number` | ✅ |
| `lat2` | `number` | ✅ |
| `lng2` | `number` | ✅ |

### `getStaticMapUrl` — Generate static map image URL
| Param | Type | Default |
|-------|------|---------|
| `latitude` | `number` | ✅ required |
| `longitude` | `number` | ✅ required |
| `zoom` | `number` | `14` |
| `width` | `number` | `600` |
| `height` | `number` | `400` |
| `mapType` | `string` | `"roadmap"` |

### `getInfo`

**Returns:** `{ name, version, configured }`

## Usage
```javascript
await NativeSDK.googleMaps.configure({ apiKey: 'AIza...' });

// Geocode address
const { latitude, longitude } = await NativeSDK.googleMaps.geocode('Tehran, Iran');
showOnMap(latitude, longitude);

// Reverse geocode
const { formattedAddress } = await NativeSDK.googleMaps.reverseGeocode(35.6892, 51.3890);
document.getElementById('address').textContent = formattedAddress;

// Directions
const route = await NativeSDK.googleMaps.getDirections('Tehran', 'Isfahan', 'driving');
console.log(`Distance: ${route.distance.text}, ETA: ${route.duration.text}`);

// Nearby search
const { places } = await NativeSDK.googleMaps.searchPlaces('coffee shop', {
  latitude: 35.6892, longitude: 51.3890, radius: 1000
});
places.forEach(p => addMarker(p.latitude, p.longitude, p.name));

// Distance calculation (no API)
const { distanceKm } = NativeSDK.googleMaps.calculateDistance(35.69, 51.39, 32.65, 51.67);

// Static map for sharing
const { url } = NativeSDK.googleMaps.getStaticMapUrl(35.6892, 51.3890, { zoom: 15 });
```
