import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

class WeatherService {
  static const String baseUrl = 'https://api.open-meteo.com/v1';

  Future<WeatherData?> fetchCurrentWeather(double lat, double lng) async {
    try {
      final url = Uri.parse(
        '$baseUrl/forecast?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min'
        '&timezone=auto&forecast_days=3',
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
        return WeatherData.fromOpenMeteo(data);
      } else {
        throw Exception('Weather API returned status ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Weather service error: $e');
      }
      return null;
    }
  }
}
