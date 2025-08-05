// lib/agent.dart
import 'package:flutter_gemma/flutter_gemma.dart'; // Add this import

class Agent {
  final String name;
  final String persona;
  final List<Tool>? tools; // ADD THIS LINE

  Agent({
    required this.name,
    required this.persona,
    this.tools, // ADD THIS LINE
  });
}