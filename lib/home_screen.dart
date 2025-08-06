// lib/home_screen.dart
import 'agent.dart';
import 'chat_message.dart';
import 'chat_screen.dart';
import 'hive_service.dart';
import 'icon_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:hive_flutter/hive_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final textController = TextEditingController();
  bool isCreating = false;

  @override
  void initState() {
    super.initState();
    _addDefaultAgentsIfEmpty();
  }

  void _addDefaultAgentsIfEmpty() {
    final agentBox = HiveService.getAgentBox();
    if (agentBox.isEmpty) {
      print("Agent box is empty. Adding default agents...");
      agentBox.add(Agent()
        ..name = 'Helpful Assistant'
        ..persona = 'You are a helpful and friendly assistant.'
        ..toolNames = []
        ..iconName = 'chat_bubble'
        ..history = []); // Initialize history
      agentBox.add(Agent()
        ..name = 'Image Analyst'
        ..persona = 'You are an expert at analyzing and describing images in detail. When the user provides an image, describe what you see with rich detail.'
        ..toolNames = []
        ..iconName = 'image'
        ..history = []); // Initialize history
      agentBox.add(Agent()
        ..name = 'Device Controller'
        ..persona = 'You are a helpful assistant that can control device features. You have access to a tool called `toggle_flashlight` to turn the flashlight on or off.'
        ..toolNames = ['toggle_flashlight']
        ..iconName = 'lightbulb'
        ..history = []); // Initialize history
      agentBox.add(Agent()
        ..name = 'Live Weather Reporter'
        ..persona = 'You are a function-calling AI assistant. Your ONLY job is to identify and call the correct tool from the provided list. You have the following tools available: `get_current_weather`. When a user asks "what is the weather in Paris?", you MUST respond ONLY with the function call. Example of a correct response format: `get_current_weather(location="Paris")`. You MUST NOT add any prefixes like `print()` or `weather.`. You MUST NOT use markdown `tool_code` blocks. Your entire response must be the raw function call.'
        ..toolNames = ['get_current_weather']
        ..iconName = 'cloud'
        ..history = []); // Initialize history
    }
  }

  Future<void> createAgent() async {
    if (textController.text.isEmpty) return;
    setState(() => isCreating = true);

    final userPrompt = textController.text;
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    String errorMessage = 'Failed to create agent. Please check your API key.';

    if (apiKey == null) {
      print('API Key not found.');
      setState(() => isCreating = false);
      return;
    }
    try {
      final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);

      final metaPrompt =
          'You are an AI Agent Persona generator. The user will provide a brief description of an agent. Your task is to generate a detailed system prompt for that agent. The system prompt should be a concise paragraph that instructs another AI on how to behave, written in the second person ("You are..."). Do not add any extra text, headings, or quotation marks. Just the persona. Here is the user\'s description: "$userPrompt"';

      final response = await model.generateContent([Content.text(metaPrompt)]);

      if (response.promptFeedback?.blockReason != null) {
        errorMessage = 'Your prompt was blocked by safety filters. Please try a different description.';
        throw Exception(errorMessage);
      }

      final newPersona = response.text;
      if (newPersona != null && newPersona.isNotEmpty) {

        final iconNames = IconService.iconMap.keys.toList().join(', ');
        final iconPrompt = 'Based on the agent description "$userPrompt", which of the following icons is the most appropriate? Respond with ONLY the name of the icon from this list: [$iconNames]';

        final iconResponse = await model.generateContent([Content.text(iconPrompt)]);
        final chosenIconName = IconService.iconMap.containsKey(iconResponse.text?.trim())
            ? iconResponse.text!.trim()
            : 'chat_bubble';

        print('AI chose icon: $chosenIconName');

        final newAgent = Agent()
          ..name = userPrompt
          ..persona = newPersona
          ..toolNames = []
          ..iconName = chosenIconName
          ..history = []; // Initialize history for new agents
        await HiveService.addAgent(newAgent);
        textController.clear();
      } else {
        errorMessage = 'The response was empty or blocked by safety filters.';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error creating agent: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => isCreating = false);
    }
  }

  void _showDeleteConfirmation(int index, Agent agent) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Agent?'),
          content: Text('Are you sure you want to delete "${agent.name}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                HiveService.deleteAgent(index);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset All Agents?'),
          content: const Text('Are you sure you want to delete all custom agents and restore the default set? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reset'),
              onPressed: () async {
                await HiveService.clearAllAgents();
                _addDefaultAgentsIfEmpty();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My AI Agents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to Defaults',
            onPressed: _showResetConfirmation,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: HiveService.getAgentBox().listenable(),
              builder: (context, Box<Agent> box, _) {
                final agents = box.values.toList();
                return ListView.builder(
                  itemCount: agents.length,
                  itemBuilder: (context, index) {
                    final agent = agents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      child: ListTile(
                        leading: Icon(agent.iconData, color: Theme.of(context).colorScheme.primary),
                        title: Text(agent.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(agent.persona, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => ChatScreen(agent: agent)),
                          );
                        },
                        onLongPress: () {
                          _showDeleteConfirmation(index, agent);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Material(
            elevation: 8.0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        hintText: 'Create an agent, e.g., "a travel planner"',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) => createAgent(),
                    ),
                  ),
                  isCreating
                      ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                      : IconButton(
                    icon: const Icon(Icons.add_circle, size: 30),
                    onPressed: createAgent,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}