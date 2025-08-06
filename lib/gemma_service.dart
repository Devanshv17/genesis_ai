// lib/gemma_service.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:genesis_ai/agent.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

class GemmaService {
  static InferenceModel? model;
  static var _activeChat;
  // --- FIX: Removed the redundant subscription variable from the service. ---
  // The ChatScreen will manage its own subscription lifecycle.

  static Future<void> setupModelPath() async {
    final modelManager = FlutterGemmaPlugin.instance.modelManager;
    final directory = await getApplicationDocumentsDirectory();
    const modelFilename = 'gemma-3n-E2B-it-int4.task';
    final filePath = '${directory.path}/$modelFilename';
    await modelManager.setModelPath(filePath);
    print('GemmaService: Model file path configured at $filePath');
  }

  static Future<void> startChatSession(Agent agent) async {
    print("GEMMA_SERVICE: Starting new chat session for '${agent.name}'...");
    await stopChatSession();

    try {
      print("GEMMA_SERVICE: Creating new InferenceModel instance.");
      model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        supportImage: true,
      );
      print('GemmaService: Shared InferenceModel created successfully.');

      _activeChat = await model!.createChat(
        supportImage: true,
        tools: agent.tools,
        supportsFunctionCalls: agent.tools.isNotEmpty,
      );

      await _activeChat!.addQueryChunk(Message.text(text: agent.persona, isUser: true));
      for (final message in agent.history) {
        if (message.imageBytes != null) {
          await _activeChat!.addQueryChunk(Message.withImage(text: message.text, imageBytes: message.imageBytes!, isUser: message.isUser));
        } else {
          await _activeChat!.addQueryChunk(Message.text(text: message.text, isUser: message.isUser));
        }
      }
      print("GEMMA_SERVICE: Chat session for '${agent.name}' is ready.");
    } catch (e) {
      print("GEMMA_SERVICE: ERROR - Failed to create chat session: $e");
      _activeChat = null;
    }
  }

  static Stream<dynamic>? generateResponse(String text, Uint8List? imageBytes) {
    if (_activeChat == null) {
      print("GEMMA_SERVICE: ERROR - No active chat session.");
      return null;
    }
    if (imageBytes != null) {
      _activeChat!.addQueryChunk(Message.withImage(text: text, imageBytes: imageBytes, isUser: true));
    } else {
      _activeChat!.addQueryChunk(Message.text(text: text, isUser: true));
    }
    return _activeChat!.generateChatResponseAsync();
  }

  static Stream<dynamic>? sendToolResultAndGetResponse({
    required String toolName,
    required Map<String, dynamic> response,
  }) {
    if (_activeChat == null) {
      print("GEMMA_SERVICE: ERROR - No active chat session to send tool result to.");
      return null;
    }
    print("GEMMA_SERVICE: Sending tool result for '$toolName' back to model.");
    final toolMessage = Message.toolResponse(toolName: toolName, response: response);
    _activeChat!.addQueryChunk(toolMessage);
    return _activeChat!.generateChatResponseAsync();
  }

  static Future<void> addModelResponseToHistory(String text) async {
    if (_activeChat == null) return;
    await _activeChat!.addQueryChunk(Message.text(text: text, isUser: false));
  }

  static Future<void> stopChatSession() async {
    print("GEMMA_SERVICE: Stopping active chat session...");
    // --- FIX: Removed subscription cancellation from here. ---
    await model?.close();
    model = null;
    _activeChat = null;
    print("GEMMA_SERVICE: Active chat session and model resources released.");
  }
}