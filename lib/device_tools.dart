import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';

class DeviceTools {
  // Your original flashlight function
  static Future<Map<String, dynamic>> toggleFlashlight({bool isOn = false}) async {
    PermissionStatus status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (status.isGranted) {
      try {
        if (isOn) {
          await TorchLight.enableTorch();
          return {'status': 'success', 'message': 'Flashlight was turned on.'};
        } else {
          await TorchLight.disableTorch();
          return {'status': 'success', 'message': 'Flashlight was turned off.'};
        }
      } on Exception catch (e) {
        return {'status': 'error', 'message': 'Could not access flashlight: ${e.toString()}'};
      }
    } else {
      return {'status': 'error', 'message': 'Camera permission was denied. Cannot use the flashlight.'};
    }
  }

  // The new weather function, now correctly placed inside the class
  static Future<Map<String, dynamic>> getCurrentWeather({required String location}) async {
    final apiKey = dotenv.env['WEATHER_API_KEY'];
    if (apiKey == null) {
      return {'error': 'API Key not found'};
    }
    final url = Uri.parse('http://api.weatherapi.com/v1/current.json?key=$apiKey&q=$location&aqi=no');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tempC = data['current']['temp_c'];
        final condition = data['current']['condition']['text'];
        return {
          'location': data['location']['name'],
          'temperature_celsius': tempC,
          'condition': condition,
        };
      } else {
        return {'error': 'Failed to get weather data. Status code: ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'An exception occurred: ${e.toString()}'};
    }
  }
}