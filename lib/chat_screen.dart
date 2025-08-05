import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Required for image bytes
import 'package:flutter_gemma/core/model.dart';

import 'agent.dart';
import 'chat_message.dart';
import 'device_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:image_picker/image_picker.dart'; // Import the image_picker package
import 'package:path_provider/path_provider.dart';

class ChatScreen extends StatefulWidget {
  final Agent agent;
  const ChatScreen({super.key, required this.agent});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  InferenceModel? _inferenceModel;
  var _chat;
  String _status = 'Initializing...';
  bool _isReady = false;
  bool _isModelResponding = false;

  final textController = TextEditingController();
  final List<ChatMessage> messages = [];
  final ScrollController _scrollController = ScrollController();

  // State variable to hold the selected image
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => initializeGemma());
  }

  @override
  void dispose() {
    _inferenceModel?.close();
    textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> initializeGemma() async {
    setState(() => _status = 'Loading ${widget.agent.name}...');
    try {
      final directory = await getApplicationDocumentsDirectory();
      const modelFilename = 'gemma-3n-E2B-it-int4.task';
      final filePath = '${directory.path}/$modelFilename';
      await FlutterGemmaPlugin.instance.modelManager.setModelPath(filePath);

      _inferenceModel = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        supportImage: true,
      );

      _chat = await _inferenceModel!.createChat(
        supportImage: true,
        tools: widget.agent.tools ?? [],
      );

      await _chat.addQueryChunk(Message.text(text: widget.agent.persona, isUser: true));

      setState(() {
        _isReady = true;
        _status = 'Ready to chat!';
      });
    } catch (e) {
      print('[ERROR] An error occurred during initialization: $e');
      setState(() => _status = 'Error initializing AI. Please restart.');
    }
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

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxHeight: 1024);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  void sendMessage() async {
    if (!_isReady || _isModelResponding || (textController.text.isEmpty && _imageBytes == null) || _chat == null) return;

    final userMessageText = textController.text;

    setState(() {
      messages.add(ChatMessage(text: userMessageText, isUser: true));
      textController.clear();
      _isModelResponding = true;
    });

    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
    await _generateResponse(userMessageText, _imageBytes);

    // Clear the image after sending
    setState(() {
      _imageBytes = null;
    });
  }

  Future<void> _generateResponse(String userMessageText, Uint8List? imageBytes) async {
    // Logic to handle images
    if (imageBytes != null) {
      await _chat.addQueryChunk(Message.withImage(
          text: userMessageText,
          imageBytes: imageBytes,
          isUser: true
      ));
    } else {
      await _chat.addQueryChunk(Message.text(text: userMessageText, isUser: true));
    }

    setState(() => messages.add(ChatMessage(text: '…', isUser: false)));

    try {
      final responseStream = _chat.generateChatResponseAsync();

      String fullResponse = '';
      await for (final tokenResponse in responseStream) {
        if (tokenResponse is FunctionCallResponse) {
          await _handleFunctionCall(tokenResponse);
          return;
        } else if (tokenResponse is TextResponse) {
          fullResponse += tokenResponse.token;
          setState(() {
            messages.last = ChatMessage(text: fullResponse + '…', isUser: false);
          });
          _scrollToBottom();
        }
      }

      setState(() {
        messages.last = ChatMessage(text: fullResponse, isUser: false);
      });

      final wasHandledAsFunction = await _parseAndHandleTextFunctionCall(fullResponse);

      if (!wasHandledAsFunction) {
        setState(() => _isModelResponding = false);
      }

    } catch (e) {
      print('[getResponse] CAUGHT ERROR: $e');
      setState(() {
        messages.last = ChatMessage(text: 'Sorry, an error occurred.', isUser: false);
        _isModelResponding = false;
      });
    }
    _scrollToBottom();
  }

  Future<bool> _parseAndHandleTextFunctionCall(String text) async {
    final regex = RegExp(r'(\w+)\((.*)\)');
    final match = regex.firstMatch(text.trim());

    if (match != null) {
      final functionName = match.group(1);
      final argsString = match.group(2);

      if (functionName == null || argsString == null) return false;

      Map<String, dynamic> args = {};
      final argRegex = RegExp(r'(\w+)\s*=\s*"([^"]*)"');
      final argMatches = argRegex.allMatches(argsString);
      for (final argMatch in argMatches) {
        args[argMatch.group(1)!] = argMatch.group(2)!;
      }

      print('--- PARSED FUNCTION CALL FROM TEXT ---');
      print('Name: $functionName');
      print('Arguments: $args');
      print('------------------------------------');

      final functionCall = FunctionCallResponse(name: functionName, args: args);
      await _handleFunctionCall(functionCall);
      return true;
    }
    return false;
  }

  Future<void> _handleFunctionCall(FunctionCallResponse functionCall) async {
    setState(() => messages.last = ChatMessage(text: 'Activating tool: ${functionCall.name}...', isUser: false));
    Map<String, dynamic> toolResponse;

    switch (functionCall.name) {
      case 'toggle_flashlight':
        final isOn = (functionCall.args['isOn'] is bool) ? functionCall.args['isOn'] : (functionCall.args['isOn'].toString().toLowerCase() == 'true');
        toolResponse = await DeviceTools.toggleFlashlight(isOn: isOn);
        break;
      case 'get_current_weather':
        final location = functionCall.args['location'] as String? ?? '';
        toolResponse = await DeviceTools.getCurrentWeather(location: location);
        break;
      default:
        toolResponse = {'error': 'Unknown function: ${functionCall.name}'};
    }

    final String formattedResponse = "I have executed the tool '${functionCall.name}' and received the following result: ${jsonEncode(toolResponse)}. Now, provide a user-friendly summary of this result.";

    await _chat.addQueryChunk(Message.text(text: formattedResponse, isUser: true));

    await _getFinalSummary();
  }

  Future<void> _getFinalSummary() async {
    final modelResponseHolder = ChatMessage(text: '…', isUser: false);
    setState(() => messages.add(modelResponseHolder));

    try {
      final responseStream = _chat.generateChatResponseAsync();
      String fullResponse = '';
      await for (final tokenResponse in responseStream) {
        if (tokenResponse is TextResponse) {
          setState(() {
            fullResponse += tokenResponse.token;
            messages.last = ChatMessage(text: fullResponse + '…', isUser: false);
          });
          _scrollToBottom();
        }
      }
      setState(() {
        messages.last = ChatMessage(text: fullResponse, isUser: false);
        _isModelResponding = false;
      });
    } catch (e) {
      print('[getFinalSummary] CAUGHT ERROR: $e');
      setState(() {
        messages.last = ChatMessage(text: 'Sorry, an error occurred after the tool ran.', isUser: false);
        _isModelResponding = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final bool canSendMessage = _isReady && !_isModelResponding;
    return Scaffold(
      appBar: AppBar(title: Text(widget.agent.name)),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(child: Text(_status))
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Align(
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
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
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
                        Image.memory(_imageBytes!),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                            onPressed: () => setState(() => _imageBytes = null),
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
                          hintText: canSendMessage ? 'Ask a question...' : 'AI is responding...',
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: canSendMessage ? (_) => sendMessage() : null,
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