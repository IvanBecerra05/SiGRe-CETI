import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // 🔑 REEMPLAZA CON TU API KEY de OpenWeatherMap
  static const String _apiKey = 'd52a0f0028a4bce4dda29d3241c32789';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  
  // Coordenadas de Tlaquepaque, Jalisco
  static const double _lat = 20.6401;
  static const double _lon = -103.3125;

  /// Obtiene temperatura actual en °C y calidad del aire
  static Future<Map<String, dynamic>?> obtenerDatosAmbientales() async {
    try {
      // Llamada para clima (temperatura)
      final weatherUrl = Uri.parse(
        '$_baseUrl/weather?lat=$_lat&lon=$_lon&appid=$_apiKey&units=metric&lang=es',
      );
      
      final weatherResponse = await http.get(weatherUrl);
      
      if (weatherResponse.statusCode != 200) {
        print('❌ Error clima: ${weatherResponse.statusCode}');
        print('Respuesta: ${weatherResponse.body}');
        return null;
      }
      
      print('✅ Clima obtenido correctamente');
      
      final weatherData = json.decode(weatherResponse.body);
      
      // Llamada para calidad del aire
      final aqiUrl = Uri.parse(
        '$_baseUrl/air_pollution?lat=$_lat&lon=$_lon&appid=$_apiKey',
      );
      
      final aqiResponse = await http.get(aqiUrl);
      
      if (aqiResponse.statusCode != 200) {
        print('❌ Error AQI: ${aqiResponse.statusCode}');
        print('Respuesta: ${aqiResponse.body}');
        return null;
      }
      
      print('✅ AQI obtenido correctamente');
      
      final aqiData = json.decode(aqiResponse.body);
      
      // Extraer datos relevantes
      final temperatura = weatherData['main']['temp'].toDouble();
      final aqiIndex = aqiData['list'][0]['main']['aqi'] as int;
      
      return {
        'temperatura': temperatura,
        'aqi': aqiIndex,
        'aqiDescripcion': _obtenerDescripcionAQI(aqiIndex),
        'aqiColor': _obtenerColorAQI(aqiIndex),
      };
    } catch (e) {
      print('Error obteniendo datos ambientales: $e');
      return null;
    }
  }

  /// Convierte el índice AQI a descripción en español
  static String _obtenerDescripcionAQI(int aqi) {
    switch (aqi) {
      case 1:
        return 'Buena';
      case 2:
        return 'Moderada';
      case 3:
        return 'Regular';
      case 4:
        return 'Mala';
      case 5:
        return 'Muy mala';
      default:
        return 'Desconocida';
    }
  }

  /// Obtiene color según índice AQI
  static int _obtenerColorAQI(int aqi) {
    switch (aqi) {
      case 1:
        return 0xFF4CAF50; // Verde
      case 2:
        return 0xFF8BC34A; // Verde claro
      case 3:
        return 0xFFFFC107; // Amarillo
      case 4:
        return 0xFFFF9800; // Naranja
      case 5:
        return 0xFFF44336; // Rojo
      default:
        return 0xFF9E9E9E; // Gris
    }
  }
}