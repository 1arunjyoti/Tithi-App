import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

enum WeatherErrorType { timeout, network, server, parsing, unknown }

class WeatherError {
  final WeatherErrorType type;
  final String message;
  final int? statusCode;

  const WeatherError({
    required this.type,
    required this.message,
    this.statusCode,
  });
}

sealed class WeatherResult {
  const WeatherResult();
}

class WeatherSuccess extends WeatherResult {
  final WeatherData data;

  const WeatherSuccess(this.data);
}

class WeatherFailure extends WeatherResult {
  final WeatherError error;

  const WeatherFailure(this.error);
}

class WeatherService {
  static const String baseUrl = 'https://api.open-meteo.com/v1';

  Future<WeatherResult> fetchCurrentWeather(double lat, double lng) async {
    try {
      final url = Uri.parse(
        '$baseUrl/forecast?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min'
        '&timezone=auto&forecast_days=3',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          return WeatherSuccess(WeatherData.fromOpenMeteo(data));
        } catch (e) {
          return WeatherFailure(
            WeatherError(
              type: WeatherErrorType.parsing,
              message: 'Weather response parsing failed: $e',
            ),
          );
        }
      } else {
        return WeatherFailure(
          WeatherError(
            type: WeatherErrorType.server,
            message: 'Weather API returned status ${response.statusCode}',
            statusCode: response.statusCode,
          ),
        );
      }
    } on TimeoutException {
      return const WeatherFailure(
        WeatherError(
          type: WeatherErrorType.timeout,
          message: 'Weather API request timed out',
        ),
      );
    } on http.ClientException catch (e) {
      return WeatherFailure(
        WeatherError(
          type: WeatherErrorType.network,
          message: 'Weather network error: $e',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Weather service error: $e');
      }
      return WeatherFailure(
        WeatherError(type: WeatherErrorType.unknown, message: '$e'),
      );
    }
  }
}
