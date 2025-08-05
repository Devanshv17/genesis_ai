import 'agent.dart';
import 'chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final textController = TextEditingController();
  bool isCreating = false;

  final List<Agent> agents = [
    Agent(
      name: 'Helpful Assistant',
      persona: 'You are a helpful and friendly assistant.',
    ),
    Agent(
      name: 'Device Controller',
      persona: 'You are a helpful assistant that can control device features. You have access to a tool called `toggle_flashlight` to turn the flashlight on or off.',
      tools: const [
        gemma.Tool(
          name: 'toggle_flashlight',
          description: "Turns the device's flashlight on or off.",
          parameters: {
            'type': 'object',
            'properties': {
              'isOn': {
                'type': 'boolean',
                'description': 'Set to true to turn the flashlight on, false to turn it off.',
              },
            },
            'required': ['isOn'],
          },
        ),
      ],
    ),
    Agent(
      name: 'Live Weather Reporter',
      persona: 'You are a function-calling AI assistant. Your ONLY job is to identify and call the correct tool from the provided list. You have the following tools available: `get_current_weather`. When a user asks "what is the weather in Paris?", you MUST respond ONLY with the function call. Example of a correct response format: `get_current_weather(location="Paris")`. You MUST NOT add any prefixes like `print()` or `weather.`. You MUST NOT use markdown `tool_code` blocks. Your entire response must be the raw function call.',
      tools: const [
        gemma.Tool(
          name: 'get_current_weather',
          description: "Gets the current weather for a specified location.",
          parameters: {
            'type': 'object',
            'properties': {
              'location': {
                'type': 'string',
                'description': 'The city and state, or city and country, e.g., San Francisco, CA or London, UK',
              },
            },
            'required': ['location'],
          },
        ),
      ],
    ),
    Agent(
      name: 'Image Analyst',
      persona: 'You are an expert at analyzing and describing images in detail. When the user provides an image, describe what you see with rich detail.',
    ),
    Agent(
      name: 'Riddle Master',
      persona: 'You are the Riddle Master. Your only purpose is to provide clever riddles to the user and give them hints if they ask. Always speak in a mysterious and playful tone.',
    ),
  ];

  Future<void> createAgent() async {
    if (textController.text.isEmpty) return;

    setState(() => isCreating = true);

    final userPrompt = textController.text;
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    String errorMessage = 'Failed to create agent. Please check your API key and connection.';

    if (apiKey == null) {
      print('API Key not found.');
      setState(() => isCreating = false);
      return;
    }

    try {
      // UPDATED to use the latest and most powerful model
      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);

      final metaPrompt =
          'You are an AI Agent Persona generator. The user will provide a brief description of an agent. Your task is to generate a detailed system prompt for that agent. The system prompt should be a concise paragraph that instructs another AI on how to behave, written in the second person ("You are..."). Do not add any extra text, headings, or quotation marks. Just the persona. Here is the user\'s description: "$userPrompt"';

      final response = await model.generateContent([Content.text(metaPrompt)]);

      if (response.promptFeedback?.blockReason != null) {
        errorMessage = 'Your prompt was blocked by safety filters. Please try a different description.';
        throw Exception(errorMessage);
      }

      final newPersona = response.text;

      if (newPersona != null && newPersona.isNotEmpty) {
        setState(() {
          agents.add(Agent(name: userPrompt, persona: newPersona));
          textController.clear();
        });
        print('Generated Persona: $newPersona');
      } else {
        errorMessage = 'The response was blocked by safety filters. Please try a different description.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My AI Agents'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: agents.length,
              itemBuilder: (context, index) {
                final agent = agents[index];
                return ListTile(
                  leading: Icon(
                      agent.tools != null ? Icons.build_circle_outlined : Icons.chat_bubble_outline_rounded
                  ),
                  title: Text(agent.name),
                  subtitle: Text(agent.persona, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => ChatScreen(agent: agent)),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      hintText: 'Create an agent, e.g., "a cheerful poet"',
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
                  icon: const Icon(Icons.add),
                  onPressed: createAgent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}