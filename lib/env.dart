// lib/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
final class Env {
  @EnviedField(varName: 'GEMINI_API_KEY', obfuscate: true)
  static final String geminiApiKey = _Env.geminiApiKey;

  @EnviedField(varName: 'WEATHER_API_KEY', obfuscate: true)
  static final String weatherApiKey = _Env.weatherApiKey;

  @EnviedField(varName: 'HF_TOKEN', obfuscate: true)
  static final String hfToken = _Env.hfToken;
}