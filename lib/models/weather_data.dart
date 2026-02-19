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

  factory WeatherData.fromOpenMeteo(Map<String, dynamic> json) {
    final current = json['current'];
    final daily = json['daily'];

    final conditionCode = current['weather_code'] as int;
    final condition = _getConditionFromCode(conditionCode);

    List<DailyForecast> forecastList = [];
    if (daily != null) {
      final dates = daily['time'] as List;
      final maxTemps = daily['temperature_2m_max'] as List;
      final minTemps = daily['temperature_2m_min'] as List;
      final codes = daily['weather_code'] as List;

      for (int i = 1; i < dates.length && i < 3; i++) {
        final forecastCondition = _getConditionFromCode(codes[i] as int);
        forecastList.add(DailyForecast(
          date: DateTime.parse(dates[i]),
          maxTemp: (maxTemps[i] as num).toDouble(),
          minTemp: (minTemps[i] as num).toDouble(),
          conditionText: forecastCondition.$1,
          conditionIcon: _getConditionIcon(forecastCondition.$2),
        ));
      }
    }

    return WeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),
      conditionText: condition.$1,
      conditionIcon: _getConditionIcon(condition.$2),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      uv: 0,
      forecast: forecastList,
    );
  }

  static (String, int) _getConditionFromCode(int code) {
    switch (code) {
      case 0:
        return ('Clear sky', 1000);
      case 1:
        return ('Mainly clear', 1000);
      case 2:
        return ('Partly cloudy', 1003);
      case 3:
        return ('Overcast', 1006);
      case 45:
      case 48:
        return ('Foggy', 1135);
      case 51:
      case 53:
      case 55:
        return ('Drizzle', 1063);
      case 56:
      case 57:
        return ('Freezing drizzle', 1069);
      case 61:
      case 63:
      case 65:
        return ('Rain', 1183);
      case 66:
      case 67:
        return ('Freezing rain', 1066);
      case 71:
      case 73:
      case 75:
        return ('Snowfall', 1066);
      case 77:
        return ('Snow grains', 1066);
      case 80:
      case 81:
      case 82:
        return ('Rain showers', 1186);
      case 85:
      case 86:
        return ('Snow showers', 1066);
      case 95:
        return ('Thunderstorm', 1087);
      case 96:
      case 99:
        return ('Thunderstorm with hail', 1087);
      default:
        return ('Unknown', 1000);
    }
  }

  static String _getConditionIcon(int weatherApiCode) {
    return 'https://cdn.weatherapi.com/weather/64x64/day/$weatherApiCode.png';
  }
}
