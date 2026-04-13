import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

class WeatherData {
  final double tempF;
  final double tempC;
  final String condition;
  final String icon;
  final int humidity;
  final double windMph;
  final String city;

  const WeatherData({
    required this.tempF,
    required this.tempC,
    required this.condition,
    required this.icon,
    required this.humidity,
    required this.windMph,
    required this.city,
  });

  String get tempDisplay => '${tempF.round()}°F';

  String get dressAdvice {
    if (tempF >= 85) return 'Hot — light, breathable fabrics';
    if (tempF >= 70) return 'Warm — short sleeves, light layers';
    if (tempF >= 55) return 'Mild — layer up, light jacket';
    if (tempF >= 40) return 'Cool — jacket or sweater weather';
    return 'Cold — heavy coat, layers, boots';
  }

  List<String> get suggestedCategories {
    if (tempF >= 80) return ['tops', 'bottoms', 'shoes', 'accessories'];
    if (tempF >= 65) return ['tops', 'bottoms', 'shoes'];
    if (tempF >= 50) return ['tops', 'bottoms', 'shoes', 'outerwear'];
    return ['tops', 'bottoms', 'shoes', 'outerwear'];
  }

  bool get needsOuterwear => tempF < 65;
}

class WeatherService {
  // Uses wttr.in — free, no API key needed
  Future<WeatherData?> getCurrentWeather({String location = ''}) async {
    try {
      final url = location.isEmpty
          ? 'https://wttr.in/?format=j1'
          : 'https://wttr.in/$location?format=j1';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final current = data['current_condition'][0];
      final area = data['nearest_area'][0];

      final tempF = double.tryParse(current['temp_F'] ?? '') ?? 70;
      final tempC = double.tryParse(current['temp_C'] ?? '') ?? 21;
      final humidity = int.tryParse(current['humidity'] ?? '') ?? 50;
      final wind = double.tryParse(current['windspeedMiles'] ?? '') ?? 5;
      final desc = (current['weatherDesc'] as List?)?.first?['value'] ?? 'Clear';
      final city = area['areaName']?[0]?['value'] ?? 'Unknown';

      String icon;
      final descLower = desc.toLowerCase();
      if (descLower.contains('sun') || descLower.contains('clear')) {
        icon = '☀️';
      } else if (descLower.contains('cloud') || descLower.contains('overcast')) {
        icon = '☁️';
      } else if (descLower.contains('rain') || descLower.contains('drizzle')) {
        icon = '🌧️';
      } else if (descLower.contains('snow')) {
        icon = '❄️';
      } else if (descLower.contains('thunder') || descLower.contains('storm')) {
        icon = '⛈️';
      } else if (descLower.contains('fog') || descLower.contains('mist')) {
        icon = '🌫️';
      } else {
        icon = '🌤️';
      }

      return WeatherData(
        tempF: tempF,
        tempC: tempC,
        condition: desc,
        icon: icon,
        humidity: humidity,
        windMph: wind,
        city: city,
      );
    } catch (_) {
      return null;
    }
  }
}
