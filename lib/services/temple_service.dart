import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/temple.dart';

class TempleService {
  // Singleton instance
  static final TempleService _instance = TempleService._internal();
  factory TempleService() => _instance;
  TempleService._internal();

  // List of available Overpass API servers
  final List<String> _overpassServers = [
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://z.overpass-api.de/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  /// Fetches Hindu temples near the given coordinates using Overpass API.
  /// [radius] is in meters.
  Future<List<Temple>> fetchNearbyTemples(
    double lat,
    double lon, {
    double radius = 5000,
  }) async {
    // Overpass QL query:
    // [out:json][timeout:25];node(around:radius,lat,lon)["amenity"="place_of_worship"]["religion"="hindu"];out;
    // Added [timeout:25] (seconds) to the query itself
    final query =
        '[out:json][timeout:25];node(around:$radius,$lat,$lon)["amenity"="place_of_worship"]["religion"="hindu"];out;';

    final encodedQuery = Uri.encodeComponent(query);

    // Try each server until success
    for (final baseUrl in _overpassServers) {
      try {
        final url = Uri.parse('$baseUrl?data=$encodedQuery');

        if (kDebugMode) {
          print('Fetching temples from: $baseUrl');
        }

        final response = await http
            .get(url)
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final elements = data['elements'] as List<dynamic>? ?? [];

          if (kDebugMode) {
            print('Found ${elements.length} temples from $baseUrl');
          }

          const Distance distanceCalculator = Distance();

          return elements.map((e) {
            final temple = Temple.fromJson(e as Map<String, dynamic>);

            // Calculate distance
            final dist = distanceCalculator.as(
              LengthUnit.Meter,
              LatLng(lat, lon),
              LatLng(temple.latitude, temple.longitude),
            );

            return Temple(
              id: temple.id,
              name: temple.name,
              latitude: temple.latitude,
              longitude: temple.longitude,
              distance: dist.toDouble(),
            );
          }).toList();
        } else if (response.statusCode == 429) {
          // Too many requests, try next server immediately
          if (kDebugMode) {
            print('Overpass 429 (Too Many Requests) from $baseUrl');
          }
          continue;
        } else if (response.statusCode >= 500) {
          // Server error, try next
          if (kDebugMode) {
            print('Overpass ${response.statusCode} from $baseUrl');
          }
          continue;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching from $baseUrl: $e');
        }
        // Connection error or timeout, try next server
        continue;
      }
    }

    // If all servers failed
    if (kDebugMode) {
      print('All Overpass servers failed');
    }
    return [];
  }
}
