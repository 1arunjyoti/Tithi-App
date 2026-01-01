class DailyForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final String conditionText;
  final String conditionIcon;

  DailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.conditionText,
    required this.conditionIcon,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    final day = json['day'];
    final condition = day['condition'];

    return DailyForecast(
      date: DateTime.parse(json['date']),
      maxTemp: (day['maxtemp_c'] as num).toDouble(),
      minTemp: (day['mintemp_c'] as num).toDouble(),
      conditionText: condition['text'],
      conditionIcon: 'https:${condition['icon']}',
    );
  }
}

class WeatherData {
  final double temperature;
  final String conditionText;
  final String conditionIcon;
  final int humidity;
  final double windSpeed;
  final double feelsLike;
  final double uv;
  final List<DailyForecast> forecast;

  WeatherData({
    required this.temperature,
    required this.conditionText,
    required this.conditionIcon,
    required this.humidity,
    required this.windSpeed,
    required this.feelsLike,
    required this.uv,
    this.forecast = const [],
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    final condition = current['condition'];

    List<DailyForecast> forecastList = [];
    if (json['forecast'] != null && json['forecast']['forecastday'] != null) {
      final days = json['forecast']['forecastday'] as List;
      // Skip today (index 0) and take next 2 days
      if (days.length > 1) {
        forecastList = days
            .skip(1)
            .take(2)
            .map((d) => DailyForecast.fromJson(d))
            .toList();
      }
    }

    return WeatherData(
      temperature: (current['temp_c'] as num).toDouble(),
      conditionText: condition['text'],
      conditionIcon: 'https:${condition['icon']}', // Add https: prefix
      humidity: (current['humidity'] as num).toInt(),
      windSpeed: (current['wind_kph'] as num).toDouble(),
      feelsLike: (current['feelslike_c'] as num).toDouble(),
      uv: (current['uv'] as num).toDouble(),
      forecast: forecastList,
    );
  }
}
