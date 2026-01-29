// lib/core/utils/location_helper.dart

import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

// Simple exception class for location errors
class LocationException implements Exception {
  LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LocationSearchResult {
  LocationSearchResult(this.position, this.matchedAddress);
  final Position position;
  final String matchedAddress;
}

class LocationHelper {
  static const double defaultRadiusKm = 3;
  static const int locationTimeoutSeconds = 30;

  /// Check and request location permissions
  static Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location permissions are permanently denied',
      );
    }

    return true;
  }

  /// Get current position
  static Future<Position> getCurrentPosition() async {
    await checkLocationPermission();

    return Geolocator.getCurrentPosition(
      timeLimit: const Duration(seconds: locationTimeoutSeconds),
    );
  }

  /// Get address from coordinates (Reverse Geocoding)
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        return 'Unknown location';
      }

      final place = placemarks[0];

      return [
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.postalCode,
        place.country,
      ].where((e) => e != null && e.isNotEmpty).join(', ');
    } catch (e) {
      throw LocationException('Failed to get address: $e');
    }
  }

  /// Calculate distance between two points in meters
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Check if location is within radius
  static bool isWithinRadius(
    double userLat,
    double userLng,
    double targetLat,
    double targetLng,
    double radiusKm,
  ) {
    final distance = calculateDistance(userLat, userLng, targetLat, targetLng);
    return distance <= (radiusKm * 1000); // Convert km to meters
  }

  /// Get coordinates from address (Forward Geocoding)
  static Future<LocationSearchResult> getCoordinatesFromAddress(
      String address,) async {
    // 1. Try Standard Geocoding (Platform)
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LocationSearchResult(
          _toPosition(locations[0].latitude, locations[0].longitude),
          address, // Assuming exact match if successful
        );
      }
    } catch (_) {
      // Continue to fallback
    }

    // 2. Try Nominatim (OSM) with Intelligent Fallback
    // If the specific address (e.g. "Building Name, Street, City") is not found,
    // we try to find the "Street, City", then "City" to at least give a result.
    var currentQuery = address;
    final dio = Dio();

    // Max 3 retry levels to avoid infinite loops or poor matches
    for (var i = 0; i < 4; i++) {
      try {
        // print('Searching location for: $currentQuery');
        final response = await dio.get(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: {
            'q': currentQuery,
            'format': 'json',
            'limit': '1',
          },
          options: Options(
            headers: {
              'User-Agent': 'OrderMate_Flutter_App/1.0',
            },
          ),
        );

        if (response.statusCode == 200 && (response.data as List).isNotEmpty) {
          final data = (response.data as List)[0] as Map<String, dynamic>;
          return LocationSearchResult(
            _toPosition(
              double.parse(data['lat'].toString()),
              double.parse(data['lon'].toString()),
            ),
            currentQuery,
          );
        }
      } catch (_) {
        // Network error, probably can't recover
        break;
      }

      // Prepare next fallback: Remove the first comma-separated part
      // e.g. "Building, Street, City" -> "Street, City"
      final firstCommaIndex = currentQuery.indexOf(',');
      if (firstCommaIndex == -1) break; // No more parts to strip

      currentQuery = currentQuery.substring(firstCommaIndex + 1).trim();
      if (currentQuery.isEmpty) break;
    }

    throw LocationException(
        'No location found for "$address" or its surrounding area.',);
  }

  static Position _toPosition(double lat, double lng) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  /// Get detailed address info from coordinates (Robust Reverse Geocoding)
  static Future<Placemark> getPlacemarkFromCoordinates(
    double lat,
    double lng,
  ) async {
    // 1. Try Standard Geocoding
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        return placemarks[0];
      }
    } catch (_) {}

    // 2. Fallback: Nominatim (OpenStreetMap)
    try {
      final dio = Dio();
      final response = await dio.get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
          'addressdetails': '1',
        },
        options: Options(
          headers: {'User-Agent': 'OrderMate_Flutter_App/1.0'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          // Construct street line
          var streetName = (address['road'] as String?) ??
              (address['pedestrian'] as String?) ??
              (address['street'] as String?) ??
              (address['residential'] as String?) ??
              (address['path'] as String?) ??
              '';

          // Fallback if specific street is missing: use neighborhood/suburb
          if (streetName.isEmpty) {
            streetName = (address['suburb'] as String?) ??
                (address['neighbourhood'] as String?) ??
                (address['city_district'] as String?) ??
                (address['village'] as String?) ??
                '';
          }

          final houseNumber = address['house_number'] as String?;
          if (houseNumber != null && streetName.isNotEmpty) {
            streetName = '$houseNumber $streetName';
          } else if (streetName.isEmpty && houseNumber != null) {
            streetName = houseNumber;
          }

          // Manually construct Placemark from OSM data
          return Placemark(
            street: streetName,
            subLocality: (address['suburb'] as String?) ??
                (address['neighbourhood'] as String?) ??
                (address['city_district'] as String?) ??
                '',
            locality: (address['city'] as String?) ??
                (address['town'] as String?) ??
                (address['village'] as String?) ??
                (address['hamlet'] as String?) ??
                '',
            administrativeArea:
                (address['state'] as String?) ?? (address['region'] as String?) ?? '',
            postalCode: (address['postcode'] as String?) ?? '',
            country: (address['country'] as String?) ?? '',
            isoCountryCode:
                (address['country_code'] as String?)?.toUpperCase() ?? '',
            name: (address['road'] as String?) ?? '',
          );
        }
      }
    } catch (_) {}

    throw LocationException(
      'Could not retrieve address details for this location.',
    );
  }
}

