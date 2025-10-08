// lib/llm_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:genesis_ai/agent.dart';
import 'gemma_service.dart';
import 'llama_sdk_service.dart';

// An abstract class that defines the contract for any LLM service we use.
abstract class LlmService {
  Future<void> initialize();
  Future<void> startChatSession(Agent agent);
  Stream<dynamic>? generateResponse(String text, Uint8List? imageBytes);
  Future<void> stopChatSession();
  Future<bool> isModelAvailable();
  String getModelName();
  String getModelDownloadUrl();
}

// A factory to get the correct service based on the platform.
LlmService getLlmService() {
  if (Platform.isAndroid || Platform.isIOS) {
    return GemmaService();
  } else if (Platform.isMacOS || Platform.isWindows) {
    return LlamaSdkService();
  } else {
    throw UnsupportedError('Unsupported platform');
  }
}