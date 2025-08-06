// lib/gemma_service.dart

import 'dart:async';
import 'dart:typed_data';

import 'agent.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

class GemmaService {
  static InferenceModel? model;
  static var _activeChat;
  static StreamSubscription? _responseSubscription;

  /// This method should only be called once when the app starts.
  /// It sets up the model path but doesn't create the model instance.
  static Future<void> setupModelPath() async {
    final modelManager = FlutterGemmaPlugin.instance.modelManager;
    final directory = await getApplicationDocumentsDirectory();
    // Ensure this model name matches the one you downloaded.
    const modelFilename = 'gemma-3n-E2B-it-int4.task';
    final filePath = '${directory.path}/$modelFilename';

    // This just tells the plugin where to find the model file.
    await modelManager.setModelPath(filePath);
    print('GemmaService: Model file path configured at $filePath');
  }

  /// This now handles the full lifecycle of creating a session for an agent.
  static Future<void> startChatSession(Agent agent) async {
    print("GEMMA_SERVICE: Starting new chat session for '${agent.name}'...");
    // First, ensure any previous session and model are completely closed.
    await stopChatSession();

    try {
      // Re-create the InferenceModel instance every time.
      // This ensures a completely fresh start with no leftover state.
      print("GEMMA_SERVICE: Creating new InferenceModel instance.");
      model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        supportImage: true,
      );
      print('GemmaService: Shared InferenceModel created successfully.');

      // Create a new chat from the fresh model instance.
      _activeChat = await model!.createChat(
        supportImage: true,
        tools: agent.tools,
        supportsFunctionCalls: agent.tools.isNotEmpty,
      );

      // Load persona and history into the new chat session.
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

  /// Sends the result of a tool call back to the model to get a final summary.
  static Stream<dynamic>? sendToolResultAndGetResponse({
    required String toolName,
    required Map<String, dynamic> response,
  }) {
    if (_activeChat == null) {
      print("GEMMA_SERVICE: ERROR - No active chat session to send tool result to.");
      return null;
    }
    print("GEMMA_SERVICE: Sending tool result for '$toolName' back to model.");
    // 1. Send the result of the tool back to the model
    final toolMessage = Message.toolResponse(toolName: toolName, response: response);
    _activeChat!.addQueryChunk(toolMessage);

    // 2. Ask the model to generate a final summary based on the tool result
    return _activeChat!.generateChatResponseAsync();
  }

  static Future<void> addModelResponseToHistory(String text) async {
    if (_activeChat == null) return;
    await _activeChat!.addQueryChunk(Message.text(text: text, isUser: false));
  }

  /// This now properly closes and releases all native resources.
  static Future<void> stopChatSession() async {
    print("GEMMA_SERVICE: Stopping active chat session...");
    await _responseSubscription?.cancel();
    _responseSubscription = null;
    _activeChat = null;

    // Close the InferenceModel to release all native resources.
    await model?.close();
    model = null; // Set the static model variable to null.

    print("GEMMA_SERVICE: Active chat session and model resources released.");
  }
}