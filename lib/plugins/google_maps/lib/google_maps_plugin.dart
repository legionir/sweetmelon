import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class GoogleMapsPlugin extends Plugin {
  String? _apiKey;

  @override
  String get name => 'googleMaps';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Google Maps geocoding, directions, and places';

  @override
  List<String> get supportedMethods => [
        'configure',
        'geocode',
        'reverseGeocode',
        'getDirections',
        'searchPlaces',
        'getPlaceDetails',
        'calculateDistance',
        'getStaticMapUrl',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'configure':
        return _configure(args);
      case 'geocode':
        return _geocode(args);
      case 'reverseGeocode':
        return _reverseGeocode(args);
      case 'getDirections':
        return _getDirections(args);
      case 'searchPlaces':
        return _searchPlaces(args);
      case 'getPlaceDetails':
        return _getPlaceDetails(args);
      case 'calculateDistance':
        return _calculateDistance(args);
      case 'getStaticMapUrl':
        return _getStaticMapUrl(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'configured': _apiKey != null,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _configure(Map<String, dynamic> args) {
    _apiKey = args['apiKey'] as String;
    BridgeLogger.info('GoogleMaps', 'Configured with API key');
    return {'configured': true};
  }

  Future<Map<String, dynamic>> _geocode(Map<String, dynamic> args) async {
    _requireApiKey();
    final address = args['address'] as String;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address)}'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final result = (data['results'] as List).first;
        final location = result['geometry']['location'];

        return {
          'found': true,
          'latitude': location['lat'],
          'longitude': location['lng'],
          'formattedAddress': result['formatted_address'],
          'placeId': result['place_id'],
        };
      }

      return {'found': false, 'status': data['status']};
    } catch (e) {
      return {'found': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _reverseGeocode(
    Map<String, dynamic> args,
  ) async {
    _requireApiKey();
    final lat = (args['latitude'] as num).toDouble();
    final lng = (args['longitude'] as num).toDouble();

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final result = (data['results'] as List).first;
        return {
          'found': true,
          'formattedAddress': result['formatted_address'],
          'placeId': result['place_id'],
          'components': _parseAddressComponents(
            result['address_components'] as List,
          ),
        };
      }

      return {'found': false, 'status': data['status']};
    } catch (e) {
      return {'found': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getDirections(
    Map<String, dynamic> args,
  ) async {
    _requireApiKey();
    final origin = args['origin'] as String;
    final destination = args['destination'] as String;
    final mode = args['mode'] as String? ?? 'driving';

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${Uri.encodeComponent(origin)}'
        '&destination=${Uri.encodeComponent(destination)}'
        '&mode=$mode'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status'] == 'OK') {
        final route = (data['routes'] as List).first;
        final leg = (route['legs'] as List).first;

        return {
          'found': true,
          'distance': leg['distance'],
          'duration': leg['duration'],
          'startAddress': leg['start_address'],
          'endAddress': leg['end_address'],
          'polyline': route['overview_polyline']?['points'],
          'steps': (leg['steps'] as List)
              .map((s) => {
                    'instruction': s['html_instructions'],
                    'distance': s['distance'],
                    'duration': s['duration'],
                    'travelMode': s['travel_mode'],
                  })
              .toList(),
        };
      }

      return {'found': false, 'status': data['status']};
    } catch (e) {
      return {'found': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _searchPlaces(
    Map<String, dynamic> args,
  ) async {
    _requireApiKey();
    final query = args['query'] as String;
    final lat = (args['latitude'] as num?)?.toDouble();
    final lng = (args['longitude'] as num?)?.toDouble();
    final radius = (args['radius'] as num?)?.toInt() ?? 5000;

    try {
      var url = 'https://maps.googleapis.com/maps/api/place/textsearch/json'
          '?query=${Uri.encodeComponent(query)}'
          '&key=$_apiKey';

      if (lat != null && lng != null) {
        url += '&location=$lat,$lng&radius=$radius';
      }

      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status'] == 'OK') {
        final places = (data['results'] as List)
            .map((p) => {
                  'name': p['name'],
                  'address': p['formatted_address'],
                  'placeId': p['place_id'],
                  'latitude': p['geometry']?['location']?['lat'],
                  'longitude': p['geometry']?['location']?['lng'],
                  'rating': p['rating'],
                  'totalRatings': p['user_ratings_total'],
                  'types': p['types'],
                  'openNow': p['opening_hours']?['open_now'],
                })
            .toList();

        return {'found': true, 'places': places, 'count': places.length};
      }

      return {'found': false, 'status': data['status']};
    } catch (e) {
      return {'found': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getPlaceDetails(
    Map<String, dynamic> args,
  ) async {
    _requireApiKey();
    final placeId = args['placeId'] as String;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status'] == 'OK') {
        final result = data['result'] as Map<String, dynamic>;
        return {
          'found': true,
          'name': result['name'],
          'address': result['formatted_address'],
          'phone': result['formatted_phone_number'],
          'website': result['website'],
          'rating': result['rating'],
          'totalRatings': result['user_ratings_total'],
          'latitude': result['geometry']?['location']?['lat'],
          'longitude': result['geometry']?['location']?['lng'],
          'types': result['types'],
          'openingHours': result['opening_hours']?['weekday_text'],
        };
      }

      return {'found': false, 'status': data['status']};
    } catch (e) {
      return {'found': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _calculateDistance(Map<String, dynamic> args) {
    final lat1 = (args['lat1'] as num).toDouble();
    final lng1 = (args['lng1'] as num).toDouble();
    final lat2 = (args['lat2'] as num).toDouble();
    final lng2 = (args['lng2'] as num).toDouble();

    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;

    return {
      'distanceMeters': distance.round(),
      'distanceKm': (distance / 1000).toStringAsFixed(2),
      'distanceMiles': (distance / 1609.344).toStringAsFixed(2),
    };
  }

  Map<String, dynamic> _getStaticMapUrl(Map<String, dynamic> args) {
    _requireApiKey();
    final lat = (args['latitude'] as num).toDouble();
    final lng = (args['longitude'] as num).toDouble();
    final zoom = (args['zoom'] as num?)?.toInt() ?? 14;
    final width = (args['width'] as num?)?.toInt() ?? 600;
    final height = (args['height'] as num?)?.toInt() ?? 400;
    final mapType = args['mapType'] as String? ?? 'roadmap';

    final url = 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng'
        '&zoom=$zoom'
        '&size=${width}x$height'
        '&maptype=$mapType'
        '&markers=color:red|$lat,$lng'
        '&key=$_apiKey';

    return {'url': url};
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  Map<String, String?> _parseAddressComponents(List components) {
    final result = <String, String?>{};
    for (final comp in components) {
      final types = comp['types'] as List;
      if (types.contains('country')) {
        result['country'] = comp['long_name'];
        result['countryCode'] = comp['short_name'];
      }
      if (types.contains('administrative_area_level_1')) {
        result['state'] = comp['long_name'];
      }
      if (types.contains('locality')) {
        result['city'] = comp['long_name'];
      }
      if (types.contains('postal_code')) {
        result['postalCode'] = comp['long_name'];
      }
      if (types.contains('route')) {
        result['street'] = comp['long_name'];
      }
    }
    return result;
  }

  void _requireApiKey() {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw const PluginException(
        code: PluginErrorCode.invalidArgs,
        message: 'Google Maps API key not configured. Call configure() first.',
      );
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'configure':
        if (args['apiKey'] is! String) {
          return ValidationResult.invalid('apiKey is required');
        }
        return ValidationResult.valid();
      case 'geocode':
        if (args['address'] is! String) {
          return ValidationResult.invalid('address is required');
        }
        return ValidationResult.valid();
      case 'reverseGeocode':
        if (args['latitude'] is! num || args['longitude'] is! num) {
          return ValidationResult.invalid('latitude and longitude required');
        }
        return ValidationResult.valid();
      case 'getDirections':
        if (args['origin'] is! String || args['destination'] is! String) {
          return ValidationResult.invalid('origin and destination required');
        }
        return ValidationResult.valid();
      case 'searchPlaces':
        if (args['query'] is! String) {
          return ValidationResult.invalid('query is required');
        }
        return ValidationResult.valid();
      case 'getPlaceDetails':
        if (args['placeId'] is! String) {
          return ValidationResult.invalid('placeId is required');
        }
        return ValidationResult.valid();
      case 'calculateDistance':
        for (final f in ['lat1', 'lng1', 'lat2', 'lng2']) {
          if (args[f] is! num) {
            return ValidationResult.invalid('$f is required');
          }
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
