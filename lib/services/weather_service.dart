import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class WeatherService {
  // Read from .env
  String get apiKey => dotenv.env['WEATHER_API_KEY'] ?? '';
  static const String baseUrl = 'https://api.weatherapi.com/v1';

  Future<WeatherData?> fetchCurrentWeather(double lat, double lng) async {
    if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
      // Return null or throw error if key is not set
      // For now, return null so we don't crash, maybe UI can show 'Set API Key'
      return null;
    }

    try {
      final url = Uri.parse(
        '$baseUrl/forecast.json?key=$apiKey&q=$lat,$lng&days=3&aqi=no&alerts=no',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      } else {
        // Handle error
        return null;
      }
    } catch (e) {
      // Handle exception
      return null;
    }
  }
}
