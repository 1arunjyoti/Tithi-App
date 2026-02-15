import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class WeatherService {
  // Read from .env
  String get apiKey => dotenv.env['WEATHER_API_KEY'] ?? '';
  static const String baseUrl = 'https://api.weatherapi.com/v1';

  Future<WeatherData?> fetchCurrentWeather(double lat, double lng) async {
    if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
      return null;
    }

    try {
      final url = Uri.parse(
        '$baseUrl/forecast.json?key=$apiKey&q=$lat,$lng&days=3&aqi=no&alerts=no',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Weather API request timed out');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      } else {
        throw Exception('Weather API returned status ${response.statusCode}');
      }
    } catch (e) {
      // Log error for debugging but don't crash the app
      if (kDebugMode) {
        print('Weather service error: $e');
      }
      return null;
    }
  }
}
