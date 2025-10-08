import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart'; // Still needed for specific response types
import 'package:image_picker/image_picker.dart';

import 'agent.dart';
import 'chat_message.dart';
import 'device_tools.dart';
import 'gemma_service.dart'; // Keep for type-checking, but not direct calls
import 'llama_sdk_service.dart';
import 'llm_service.dart'; // Import our new hybrid service

class ChatScreen extends StatefulWidget {
  final Agent agent;
  const ChatScreen({super.key, required this.agent});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // --- Start of Changes ---
  final LlmService _llmService = getLlmService(); // Get the platform-specific service
  // --- End of Changes ---

  StreamSubscription? _responseSubscription;
  String _status = 'Initializing...';
  bool _isReady = false;
  bool _isModelResponding = false;
  final textController = TextEditingController();
  final List<ChatMessage> messages = [];
  final ScrollController _scrollController = ScrollController();
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    messages.addAll(widget.agent.history);
    Future.microtask(() => initializeChat());
  }

  @override
  Future<void> dispose() async {
    await _responseSubscription?.cancel();
    // --- Use the abstract service to stop the session ---
    _llmService.stopChatSession();
    widget.agent.history = messages;
    widget.agent.save();
    textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> initializeChat() async {
    if (!mounted) return;
    setState(() => _status = 'Preparing AI session...');
    // --- Use the abstract service to start the session ---
    await _llmService.startChatSession(widget.agent);
    if (!mounted) return;
    setState(() {
      _isReady = true;
      _status = 'Ready to chat!';
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    // No changes needed here, but be aware llama_sdk will ignore the image
    if (Platform.isMacOS || Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image input is not supported on desktop.")),
      );
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxHeight: 1024);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> sendMessage() async {
    if (!_isReady ||
        _isModelResponding ||
        (textController.text.isEmpty && _imageBytes == null)) return;

    final userMessageText = textController.text;
    final userMessage = ChatMessage()
      ..text = userMessageText
      ..isUser = true
      ..imageBytes = _imageBytes;

    setState(() {
      messages.add(userMessage);
      textController.clear();
      _isModelResponding = true;
    });

    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
    _generateResponse(userMessageText, _imageBytes);

    if (!mounted) return;
    setState(() => _imageBytes = null);
  }

  void _generateResponse(String userMessageText, Uint8List? imageBytes) {
    final aiMessage = ChatMessage()..text = '…'..isUser = false;
    if (!mounted) return;
    setState(() => messages.add(aiMessage));

    // --- Use the abstract service to get the response stream ---
    final responseStream = _llmService.generateResponse(userMessageText, imageBytes);

    if (responseStream == null) {
      setState(() {
        aiMessage.text = "Error: AI Service not ready.";
        _isModelResponding = false;
      });
      return;
    }

    String fullResponse = '';
    FunctionCallResponse? receivedFunctionCall;
    bool toolCallHandled = false;

    _responseSubscription = responseStream.listen(
          (tokenResponse) {
        if (!mounted) return;

        // --- Handle different response types from each service ---
        if (tokenResponse is FunctionCallResponse) {
          toolCallHandled = true;
          receivedFunctionCall = tokenResponse;
          final functionName = tokenResponse.name;
          final functionArgs = jsonEncode(tokenResponse.args);
          final formattedCall = 'Calling Tool:\n$functionName($functionArgs)';
          setState(() => aiMessage.text = formattedCall);
        } else if (tokenResponse is TextResponse) { // From flutter_gemma
          fullResponse += tokenResponse.token;
          setState(() => aiMessage.text = fullResponse + '…');
        } else if (tokenResponse is String) { // From llama_sdk
          fullResponse += tokenResponse;
          setState(() => aiMessage.text = fullResponse + '…');
        }
        _scrollToBottom();
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          aiMessage.text = 'Sorry, an error occurred: $e';
          _isModelResponding = false;
        });
      },
      onDone: () async {
        if (!mounted) return;

        // Tool calling is only supported by GemmaService right now
        if (receivedFunctionCall != null && _llmService is GemmaService) {
          _executeToolAndGetFinalResponse(receivedFunctionCall!, aiMessage);
        } else {
          setState(() => aiMessage.text = fullResponse);
          // Add the response to the service's internal history if needed
          if (_llmService is GemmaService) {
            await (_llmService as GemmaService).addModelResponseToHistory(fullResponse);
          } else if (_llmService is LlamaSdkService) {
            await (_llmService as LlamaSdkService).addModelResponseToHistory(fullResponse);
          }
          setState(() => _isModelResponding = false);
          _scrollToBottom();
        }
      },
    );
  }

  Future<void> _executeToolAndGetFinalResponse(
      FunctionCallResponse call, ChatMessage messageToUpdate) async {
    // This function will now only be called if the service is GemmaService
    final gemmaService = _llmService as GemmaService;

    final modelJsonOutput = {
      'name': call.name,
      'parameters': call.args,
    };
    await gemmaService.addModelResponseToHistory(jsonEncode(modelJsonOutput));

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    setState(() => messageToUpdate.text = 'Running `${call.name}`... ⚙️');
    _scrollToBottom();

    Map<String, dynamic> toolResult;
    try {
      if (call.name == 'get_current_weather') {
        toolResult = await DeviceTools.getCurrentWeather(location: call.args['location']);
      } else {
        toolResult = {'error': 'Unknown tool: ${call.name}'};
      }
    } catch (e) {
      toolResult = {'error': 'App-level exception during tool execution: $e'};
    }

    final finalResponseStream = gemmaService.sendToolResultAndGetResponse(
      toolName: call.name,
      response: toolResult,
    );

    if (finalResponseStream == null) {
      setState(() => messageToUpdate.text = 'Error: Could not get final response from AI.');
      return;
    }

    String finalResponseText = '';
    await _responseSubscription?.cancel();
    _responseSubscription = finalResponseStream.listen(
          (response) {
        if (response is TextResponse) {
          finalResponseText += response.token;
          setState(() => messageToUpdate.text = finalResponseText + '…');
          _scrollToBottom();
        }
      },
      onError: (e) {
        setState(() {
          messageToUpdate.text = 'An error occurred: $e';
          _isModelResponding = false;
        });
      },
      onDone: () async {
        if (!mounted) return;
        setState(() => messageToUpdate.text = finalResponseText);
        await gemmaService.addModelResponseToHistory(finalResponseText);
        setState(() => _isModelResponding = false);
        _scrollToBottom();
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        children: [
          Icon(
            widget.agent.iconData,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            widget.agent.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.agent.persona,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatUI() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader();
        }

        final messageIndex = index - 1;
        final message = messages[messageIndex];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Align(
            alignment: message.isUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: message.isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (message.imageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxHeight: 200, maxWidth: 200),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(message.imageBytes!,
                              fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextInputBar() {
    final bool canSendMessage = _isReady && !_isModelResponding;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          if (_imageBytes != null)
            Container(
              padding: const EdgeInsets.only(bottom: 8.0),
              constraints: const BoxConstraints(maxHeight: 100),
              child: Stack(
                children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_imageBytes!)),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageBytes = null),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attachment),
                tooltip: 'Add Image',
                onPressed: canSendMessage ? _pickImage : null,
              ),
              Expanded(
                child: TextField(
                  controller: textController,
                  enabled: canSendMessage,
                  decoration: InputDecoration(
                    hintText: canSendMessage
                        ? 'Ask a question...'
                        : 'AI is responding...',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted:
                  canSendMessage ? (_) => sendMessage() : null,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: canSendMessage ? sendMessage : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.agent.name),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isReady ? _buildChatUI() : _buildLoadingState(),
          ),
          _buildTextInputBar(),
        ],
      ),
    );
  }
}