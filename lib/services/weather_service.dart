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
  // SEC-2: base URL is a named constant so it can be easily swapped or
  // overridden via --dart-define=WEATHER_BASE_URL=https://... at build time.
  static const String baseUrl = String.fromEnvironment(
    'WEATHER_BASE_URL',
    defaultValue: 'https://api.open-meteo.com/v1',
  );

  Future<WeatherResult> fetchCurrentWeather(double lat, double lng) async {
    // SEC-2: retry once on server error before giving up.
    return _doFetch(lat, lng, attempt: 1);
  }

  Future<WeatherResult> _doFetch(
    double lat,
    double lng, {
    required int attempt,
  }) async {
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
        if (attempt < 2) {
          // SEC-2: retry once on non-4xx server errors.
          await Future.delayed(const Duration(milliseconds: 500));
          return await _doFetch(lat, lng, attempt: attempt + 1);
        }
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
