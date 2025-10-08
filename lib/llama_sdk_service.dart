import 'dart:io';
import 'dart:typed_data';

import 'package:genesis_ai/agent.dart';
import 'package:genesis_ai/chat_message.dart';
import 'package:genesis_ai/llm_service.dart';
import 'package:llama_sdk/llama_sdk.dart';
import 'package:path_provider/path_provider.dart';

class LlamaSdkService implements LlmService {
  Llama? _model;
  List<ChatMessage> _messages = [];

  @override
  String getModelName() => 'model-Q4_K_M.gguf';

  @override
  String getModelDownloadUrl() =>
      'https://huggingface.co/nidum/Nidum-Llama-3.2-3B-Uncensored-GGUF/resolve/main/model-Q4_K_M.gguf';

  @override
  Future<void> initialize() async {
    print('LlamaSdkService: Ready for model loading.');
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
    print("LLAMA_SDK_SERVICE: Starting new chat session for '${agent.name}'...");
    await stopChatSession();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${getModelName()}';
      final llama = Llama(LlamaController(
        modelPath: filePath,
        nCtx: 512, // <-- FIX 1: Reduced context size for better memory management
        nBatch: 256,
        greedy: true,
      ));
      _model = llama;

      _messages = [
        ChatMessage()
          ..text = agent.persona
          ..isUser = true,
        ...agent.history,
      ];
      print("LLAMA_SDK_SERVICE: Chat session for '${agent.name}' is ready.");
    } catch (e) {
      print("LLAMA_SDK_SERVICE: ERROR - Failed to create chat session: $e");
      _model = null;
    }
  }

  String _buildLlama3Prompt(List<ChatMessage> messages) {
    // This function remains the same
    final promptBuffer = StringBuffer();
    promptBuffer.writeln('<|begin_of_text|>');
    for (final message in messages) {
      final role = message.isUser ? 'user' : 'assistant';
      promptBuffer.writeln('<|start_header_id|>$role<|end_header_id|>');
      promptBuffer.writeln('');
      promptBuffer.writeln(message.text);
      promptBuffer.writeln('<|eot_id|>');
    }
    promptBuffer.writeln('<|start_header_id|>assistant<|end_header_id|>');
    promptBuffer.writeln('');
    return promptBuffer.toString();
  }

  @override
  Stream<dynamic>? generateResponse(String text, Uint8List? imageBytes) {
    if (_model == null) {
      print("LLAMA_SDK_SERVICE: ERROR - No active chat session.");
      return null;
    }
    if (imageBytes != null) {
      print("LLAMA_SDK_SERVICE: WARNING - Image data is not supported and will be ignored.");
    }

    final newUserMessage = ChatMessage()
      ..text = text
      ..isUser = true;
    _messages.add(newUserMessage);

    // --- FIX 2: Sliding Window Logic ---
    const int maxMessagesToKeep = 10; // A safer limit for a 3B model
    if (_messages.length > maxMessagesToKeep) {
      // Remove the oldest messages, but always keep the persona (index 0)
      _messages.removeRange(1, _messages.length - maxMessagesToKeep + 1);
      print("LLAMA_SDK_SERVICE: Pruned conversation history to the latest ${maxMessagesToKeep - 1} messages.");
    }
    // --- End of Sliding Window Logic ---

    final promptString = _buildLlama3Prompt(_messages);
    final promptAsMessageList = [UserLlamaMessage(promptString)];
    return _model!.prompt(promptAsMessageList);
  }

  Stream<dynamic>? sendToolResultAndGetResponse({
    required String toolName,
    required Map<String, dynamic> response,
  }) {
    print("LLAMA_SDK_SERVICE: WARNING - Tool calling is not implemented.");
    return null;
  }

  Future<void> addModelResponseToHistory(String text) async {
    _messages.add(ChatMessage()
      ..text = text
      ..isUser = false);
    print("LLAMA_SDK_SERVICE: Added assistant response to history.");
  }

  @override
  Future<void> stopChatSession() async {
    print("LLAMA_SDK_SERVICE: Stopping active chat session...");
    _model?.stop();
    _model = null;
    _messages.clear();
    print("LLAMA_SDK_SERVICE: Active chat session and resources released.");
  }
}