// lib/chat_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_agent/agent.dart';
import 'package:ai_agent/chat_message.dart';
import 'package:ai_agent/device_tools.dart';
import 'package:ai_agent/gemma_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  final Agent agent;
  const ChatScreen({super.key, required this.agent});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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

  // --- FIX: The dispose method is now async to handle orderly shutdown ---
  @override
  Future<void> dispose() async {
    // First, await the cancellation of any active stream subscription.
    // This gives the native side time to finish its work before we shut down the service.
    await _responseSubscription?.cancel();

    // Now that the stream is safely cancelled, shut down the Gemma service.
    GemmaService.stopChatSession();

    // Perform the rest of the cleanup.
    widget.agent.history = messages;
    widget.agent.save();
    textController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> initializeChat() async {
    if (!mounted) return;
    setState(() => _status = 'Preparing AI session...');
    await GemmaService.startChatSession(widget.agent);
    if (!mounted) return;
    setState(() {
      _isReady = true;
      _status = 'Ready to chat!';
    });
  }

  // All other methods from here down are unchanged from the last version.
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

    final responseStream = GemmaService.generateResponse(userMessageText, imageBytes);

    if (responseStream == null) {
      setState(() {
        aiMessage.text = "Error: AI Service not ready.";
        _isModelResponding = false;
      });
      return;
    }

    String fullResponse = '';
    FunctionCallResponse? receivedFunctionCall;

    _responseSubscription = responseStream.listen(
          (tokenResponse) {
        if (!mounted) return;

        if (tokenResponse is FunctionCallResponse) {
          receivedFunctionCall = tokenResponse;
          final functionName = tokenResponse.name;
          final functionArgs = jsonEncode(tokenResponse.args);
          final formattedCall = 'Calling Tool:\n$functionName($functionArgs)';
          setState(() => aiMessage.text = formattedCall);

        } else if (tokenResponse is TextResponse) {
          fullResponse += tokenResponse.token;
          setState(() => aiMessage.text = fullResponse + '…');
          _scrollToBottom();
        }
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          aiMessage.text = 'Sorry, an error occurred.';
          _isModelResponding = false;
        });
      },
      onDone: () async {
        if (!mounted) return;

        if (receivedFunctionCall != null) {
          _executeToolAndGetFinalResponse(receivedFunctionCall!, aiMessage);
        } else {
          setState(() => aiMessage.text = fullResponse);
          await GemmaService.addModelResponseToHistory(fullResponse);
          setState(() => _isModelResponding = false);
          _scrollToBottom();
        }
      },
    );
  }

  Future<void> _executeToolAndGetFinalResponse(FunctionCallResponse call, ChatMessage messageToUpdate) async {
    final modelJsonOutput = {
      'name': call.name,
      'parameters': call.args,
    };
    await GemmaService.addModelResponseToHistory(jsonEncode(modelJsonOutput));

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

    final finalResponseStream = GemmaService.sendToolResultAndGetResponse(
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
          if (finalResponseText.isEmpty) {
            finalResponseText += response.token;
            setState(() => messageToUpdate.text = finalResponseText);
          } else {
            finalResponseText += response.token;
            setState(() => messageToUpdate.text = finalResponseText + '…');
          }
          _scrollToBottom();
        }
      },
      onError: (e) {
        setState(() => messageToUpdate.text = 'An error occurred: $e');
        setState(() => _isModelResponding = false);
      },
      onDone: () async {
        if (!mounted) return;
        setState(() => messageToUpdate.text = finalResponseText);
        await GemmaService.addModelResponseToHistory(finalResponseText);
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
          // Agent Icon
          Icon(
            widget.agent.iconData,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),

          // Agent Name
          Text(
            widget.agent.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Agent Persona/Description
          Text(
            widget.agent.persona,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // A subtle divider to separate the header from the chat messages
          const Divider(),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final bool canSendMessage = _isReady && !_isModelResponding;
    return Scaffold(
      appBar: AppBar(
        // The AppBar is simpler now, just showing the name.
        title: Text(widget.agent.name),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            // We use a ListView.builder for the entire scrollable area.
            child: ListView.builder(
              controller: _scrollController,
              // The item count is the number of messages PLUS ONE for the header.
              itemCount: messages.length + 1,
              itemBuilder: (context, index) {
                // --- The New Layout Logic ---

                // If it's the first item, build the header.
                if (index == 0) {
                  // If there are no messages yet, show the status in the header area.
                  return messages.isEmpty
                      ? Center(child: Text(_status))
                      : _buildHeader();
                }

                // Otherwise, it's a message. We subtract 1 to get the correct message index.
                final messageIndex = index - 1;
                final message = messages[messageIndex];

                // This is your EXACT message bubble logic from before, completely unchanged.
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
            ),
          ),

          // Your text input bar logic is completely unchanged.
          Padding(
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
          ),
        ],
      ),
    );
  }
}