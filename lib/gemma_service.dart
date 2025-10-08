import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:genesis_ai/agent.dart';
import 'package:genesis_ai/chat_message.dart';
import 'package:genesis_ai/llm_service.dart';
import 'package:path_provider/path_provider.dart';

/// An implementation of [LlmService] that uses the `flutter_gemma` package.
/// This service is intended for use on Android and iOS.
class GemmaService implements LlmService {
  InferenceModel? model;
  var _activeChat;

  @override
  String getModelName() => 'gemma-3n-E2B-it-int4.task';

  @override
  String getModelDownloadUrl() =>
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/${getModelName()}?download=true';

  @override
  Future<void> initialize() async {
    final modelManager = FlutterGemmaPlugin.instance.modelManager;
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/${getModelName()}';
    await modelManager.setModelPath(filePath);
    print('GemmaService: Model file path configured at $filePath');
  }

  @override
  Future<bool> isModelAvailable() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/${getModelName()}';
    final file = File(filePath);
    return await file.exists();
  }

  @override
  Future<void> startChatSession(Agent agent) async {
    print("GEMMA_SERVICE: Starting new chat session for '${agent.name}'...");
    await stopChatSession(); // Ensure any previous session is cleared

    try {
      print("GEMMA_SERVICE: Creating new InferenceModel instance.");
      model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        supportImage: true,
      );
      print('GemmaService: InferenceModel created successfully.');

      _activeChat = await model!.createChat(
        supportImage: true,
        tools: agent.tools,
        supportsFunctionCalls: agent.tools.isNotEmpty,
      );

      // Restore history, including agent persona
      final history = [
        ChatMessage()
          ..text = agent.persona
          ..isUser = true,
        ...agent.history
      ];

      for (final message in history) {
        if (message.imageBytes != null) {
          await _activeChat!.addQueryChunk(Message.withImage(
              text: message.text,
              imageBytes: message.imageBytes!,
              isUser: message.isUser));
        } else {
          await _activeChat!
              .addQueryChunk(Message.text(text: message.text, isUser: message.isUser));
        }
      }
      print("GEMMA_SERVICE: Chat session for '${agent.name}' is ready.");
    } catch (e) {
      print("GEMMA_SERVICE: ERROR - Failed to create chat session: $e");
      _activeChat = null;
    }
  }

  @override
  Stream<dynamic>? generateResponse(String text, Uint8List? imageBytes) {
    if (_activeChat == null) {
      print("GEMMA_SERVICE: ERROR - No active chat session.");
      return null;
    }
    if (imageBytes != null) {
      _activeChat!.addQueryChunk(
          Message.withImage(text: text, imageBytes: imageBytes, isUser: true));
    } else {
      _activeChat!.addQueryChunk(Message.text(text: text, isUser: true));
    }
    return _activeChat!.generateChatResponseAsync();
  }

  // NOTE: These methods are specific to GemmaService and its tool-calling capabilities.
  // The LlmService interface can be extended if llama_sdk also supports this.
  Stream<dynamic>? sendToolResultAndGetResponse({
    required String toolName,
    required Map<String, dynamic> response,
  }) {
    if (_activeChat == null) {
      print(
          "GEMMA_SERVICE: ERROR - No active chat session to send tool result to.");
      return null;
    }
    print("GEMMA_SERVICE: Sending tool result for '$toolName' back to model.");
    final toolMessage =
    Message.toolResponse(toolName: toolName, response: response);
    _activeChat!.addQueryChunk(toolMessage);
    return _activeChat!.generateChatResponseAsync();
  }

  Future<void> addModelResponseToHistory(String text) async {
    if (_activeChat == null) return;
    await _activeChat!.addQueryChunk(Message.text(text: text, isUser: false));
  }

  @override
  Future<void> stopChatSession() async {
    print("GEMMA_SERVICE: Stopping active chat session...");
    await model?.close();
    model = null;
    _activeChat = null;
    print("GEMMA_SERVICE: Active chat session and model resources released.");
  }
}