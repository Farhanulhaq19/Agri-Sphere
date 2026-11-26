import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Live weather from Open-Meteo (free, no API key) + simple farming advice.
class Weather {
  final double temp;
  final int humidity;
  final double wind;
  final int code;
  final List<DayForecast> days;
  const Weather({required this.temp, required this.humidity, required this.wind, required this.code, required this.days});

  String get label => weatherLabel(code);
  IconData get icon => weatherIcon(code);

  /// One practical tip for today based on rain, heat and wind.
  String get tip {
    final rain = days.isNotEmpty ? days.first.rainChance : 0;
    final rainSoon = days.take(2).any((d) => d.rainChance >= 60);
    if (rain >= 60) return 'Rain likely today: skip irrigation and delay spraying.';
    if (rainSoon) return 'Rain expected tomorrow: plan harvesting and drying today.';
    if (wind >= 25) return 'Strong wind: avoid spraying pesticides today.';
    if (temp >= 38) return 'Very hot: irrigate early morning or evening.';
    if (temp <= 5) return 'Frost risk tonight: protect young plants.';
    if (humidity >= 85) return 'High humidity: check crops for fungal disease.';
    return 'Good conditions for field work today.';
  }

  static Future<Weather> fetch(double lat, double lng) async {
    final u = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(3),
      'longitude': lng.toStringAsFixed(3),
      'current': 'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '4',
    });
    final r = await http.get(u).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) throw Exception('Weather unavailable');
    final j = jsonDecode(r.body) as Map;
    final c = j['current'] as Map;
    final d = j['daily'] as Map;
    final n = (d['time'] as List).length;
    return Weather(
      temp: (c['temperature_2m'] as num).toDouble(),
      humidity: (c['relative_humidity_2m'] as num).round(),
      wind: (c['wind_speed_10m'] as num).toDouble(),
      code: (c['weather_code'] as num).round(),
      days: List.generate(
        n,
        (i) => DayForecast(
          date: DateTime.parse('${d['time'][i]}'),
          code: (d['weather_code'][i] as num?)?.round() ?? 0,
          max: (d['temperature_2m_max'][i] as num?)?.toDouble() ?? 0,
          min: (d['temperature_2m_min'][i] as num?)?.toDouble() ?? 0,
          rainChance: (d['precipitation_probability_max'][i] as num?)?.round() ?? 0,
        ),
      ),
    );
  }
}

class DayForecast {
  final DateTime date;
  final int code;
  final double max;
  final double min;
  final int rainChance;
  const DayForecast({required this.date, required this.code, required this.max, required this.min, required this.rainChance});
}

String weatherLabel(int c) {
  if (c == 0) return 'Clear sky';
  if (c <= 2) return 'Partly cloudy';
  if (c == 3) return 'Cloudy';
  if (c == 45 || c == 48) return 'Fog';
  if (c >= 51 && c <= 57) return 'Drizzle';
  if (c >= 61 && c <= 67) return 'Rain';
  if (c >= 71 && c <= 77) return 'Snow';
  if (c >= 80 && c <= 82) return 'Rain showers';
  if (c >= 95) return 'Thunderstorm';
  return 'Cloudy';
}

IconData weatherIcon(int c) {
  if (c == 0) return Icons.wb_sunny;
  if (c <= 2) return Icons.wb_cloudy_outlined;
  if (c == 3 || c == 45 || c == 48) return Icons.cloud;
  if (c >= 95) return Icons.thunderstorm;
  if (c >= 71 && c <= 77) return Icons.ac_unit;
  return Icons.water_drop;
}
