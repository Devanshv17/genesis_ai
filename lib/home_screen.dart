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
      // agentBox.add(Agent()
      //   ..name = 'Device Controller'
      //   ..persona = 'You are a helpful assistant that can control device features. You have access to a tool called `toggle_flashlight` to turn the flashlight on or off.'
      //   ..toolNames = ['toggle_flashlight']
      //   ..iconName = 'lightbulb'
      //   ..history = []); // Initialize history
      agentBox.add(Agent()
        ..name = 'Live Weather Reporter'
        ..persona = 'You are a function-calling AI assistant. Your ONLY job is to identify and call the correct tool from the provided list. You have the following tools available: `get_current_weather`. When a user asks "what is the weather in Paris?", you MUST respond ONLY with the function call. Example of a correct response format: `get_current_weather(location="Paris")`. You MUST NOT add any prefixes like `print()` or `weather.`. You MUST NOT use markdown `tool_code` blocks. Your entire response must be the raw function call.'
        ..toolNames = ['get_current_weather']
        ..iconName = 'cloud'
        ..history = []); // Initialize history
      agentBox.add(Agent()
        ..name = 'Mindful Companion'
        ..persona = 'You are a calm, non-judgmental, and empathetic companion. Your purpose is to listen actively to the user\'s thoughts and feelings. Offer supportive and encouraging words. You can suggest simple mindfulness or breathing exercises if appropriate, but you must always include the disclaimer: "I am an AI and not a substitute for a real mental health professional."'
        ..toolNames = []
        ..iconName = 'self_improvement'
        ..history = []);

      // Accessibility Agent
      agentBox.add(Agent()
        ..name = 'Visual Companion'
        ..persona = 'You are an AI assistant designed to help visually impaired users. When the user provides an image, your only job is to describe what you see with rich, objective detail. Describe objects, people, text, colors, and the overall environment to help the user understand the scene as if they were seeing it themselves.'
        ..toolNames = []
        ..iconName = 'visibility'
        ..history = []);

      // Education Agent
      agentBox.add(Agent()
        ..name = 'Teaching Assistant'
        ..persona = 'You are an expert at simplifying complex topics. Your goal is to explain any concept the user asks about "like they\'re five years old." Use simple language, relatable analogies, and break down ideas into small, easy-to-understand parts. Avoid jargon at all costs.'
        ..toolNames = []
        ..iconName = 'school'
        ..history = []);

      // Productivity/Creative Agent
      agentBox.add(Agent()
        ..name = 'Story Starter'
        ..persona = 'You are an imaginative storyteller. When the user gives you a genre or a simple prompt, your task is to write an engaging and creative first paragraph for a story. Your goal is to spark the user\'s imagination and give them a starting point to continue writing.'
        ..toolNames = []
        ..iconName = 'auto_stories'
        ..history = []);

      // Everyday Use Agent
      agentBox.add(Agent()
        ..name = 'Kitchen Assistant'
        ..persona = 'You are a helpful and creative chef. When the user provides you with a list of ingredients they have, your job is to suggest a simple and delicious recipe they can make. List the ingredients clearly, then provide step-by-step instructions.'
        ..toolNames = []
        ..iconName = 'soup_kitchen'
        ..history = []);

      // Multilingual Agent
      agentBox.add(Agent()
        ..name = 'Language Pal (Hindi)'
        ..persona = 'You are a friendly and patient Hindi language tutor. Converse with the user in Hindi. If they make a mistake, gently correct it and briefly explain the rule. Keep the conversation simple and encouraging, focusing on common vocabulary and phrases. ...चलो अभ्यास करते हैं!'
        ..toolNames = []
        ..iconName = 'translate'
        ..history = []);
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

  // lib/home_screen.dart -> inside _HomeScreenState class

  // 1. REPLACE your old `build` method with this new one.
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
      body: ValueListenableBuilder(
        valueListenable: HiveService.getAgentBox().listenable(),
        builder: (context, Box<Agent> box, _) {
          final agents = box.values.toList();
          return GridView.builder(
            padding: const EdgeInsets.all(12.0),
            // The grid delegate defines the layout of the grid.
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Two tiles per row
              crossAxisSpacing: 12.0, // Spacing between columns
              mainAxisSpacing: 12.0,  // Spacing between rows
              childAspectRatio: 0.85, // Aspect ratio of the tiles (width / height)
            ),
            // The item count is the number of agents + 1 for our "Add" tile.
            itemCount: agents.length + 1,
            itemBuilder: (context, index) {
              // The first item (index 0) is always the "Add Agent" tile.
              if (index == 0) {
                return _AddAgentGridTile(
                  onTap: () => _showCreateAgentDialog(),
                );
              }
              // For all other items, we display an agent tile.
              // We subtract 1 from the index to get the correct agent from the list.
              final agentIndex = index - 1;
              final agent = agents[agentIndex];
              return _AgentGridTile(
                agent: agent,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(agent: agent),
                    ),
                  );
                },
                onLongPress: () {
                  _showDeleteConfirmation(agentIndex, agent);
                },
              );
            },
          );
        },
      ),
    );
  }

  // 2. ADD this new function inside your _HomeScreenState class.
  // This function shows a dialog for creating a new agent.
  // In lib/home_screen.dart, replace the existing _showCreateAgentDialog function

  void _showCreateAgentDialog() {
    final dialogTextController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              // Softer, more modern rounded corners for the dialog
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              // We use SingleChildScrollView to prevent layout issues when the keyboard appears.
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Takes up minimum vertical space
                  children: [
                    // 1. Engaging Icon
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),

                    // 2. Clear Title
                    Text(
                      'Create a New Agent',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),

                    // 3. Helpful Description
                    Text(
                      'Describe the agent you want to create in a few words. Our AI will craft the perfect persona for it.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),

                    // 4. Larger, Multi-line Text Field
                    TextField(
                      controller: dialogTextController,
                      autofocus: true,
                      keyboardType: TextInputType.multiline,
                      maxLines: 3, // Allows for more text input
                      decoration: const InputDecoration(
                        hintText: 'e.g., "a travel planner" or "a motivational fitness coach"',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center, // Center the buttons
              actions: <Widget>[
                // We keep the button logic the same, but it will now look better
                // within our improved dialog layout.
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: isCreating ? null : () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                isCreating
                    ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: CircularProgressIndicator(),
                )
                    : FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                  onPressed: () async {
                    if (dialogTextController.text.isEmpty) return;

                    textController.text = dialogTextController.text;

                    setDialogState(() => isCreating = true);
                    await createAgent();

                    // Check if the widget is still in the tree before updating state
                    if (mounted) {
                      setDialogState(() => isCreating = false);
                      // Close the dialog if agent was created successfully
                      if (textController.text.isEmpty) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 3. ADD these two new private widgets for the tiles.
  // You can place them at the bottom of the _HomeScreenState class.

  /// A widget for displaying a single agent in the grid.
  Widget _AgentGridTile({
    required Agent agent,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            // --- CHANGES ARE HERE ---
            crossAxisAlignment: CrossAxisAlignment.center, // <-- Centers all content horizontally
            children: [
              // Icon
              Icon(agent.iconData,
                  size: 48, // <-- Increased icon size
                  color: Theme.of(context).colorScheme.primary),
              const Spacer(),
              // Name
              Text(
                agent.name,
                textAlign: TextAlign.center, // <-- Aligns text to the center
                style: Theme.of(context).textTheme.titleLarge?.copyWith( // <-- Slightly larger font
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Persona
              Text(
                agent.persona,
                textAlign: TextAlign.center, // <-- Aligns text to the center
                style: Theme.of(context).textTheme.bodyMedium, // <-- Slightly larger font
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A special tile for adding a new agent.
  Widget _AddAgentGridTile({required VoidCallback onTap}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      // Dotted border effect can be achieved using a custom painter or a package,
      // but for simplicity, we'll use a standard card.
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Create New Agent',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}