import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';
import 'location_provider.dart';

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

final currentWeatherProvider = FutureProvider<WeatherData?>((ref) async {
  final service = ref.watch(weatherServiceProvider);
  final coordsAsync = ref.watch(coordinatesProvider);
  final coords = coordsAsync.asData?.value;

  if (coords == null) {
    return null;
  }

  final lat = coords.latitude;
  final lng = coords.longitude;

  // You might want to debounce or cache this, but for now basic fetch
  return service.fetchCurrentWeather(lat, lng);
});
