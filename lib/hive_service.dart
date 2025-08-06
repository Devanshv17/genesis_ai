import 'package:ai_agent/agent.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String agentBoxName = 'agents';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(AgentAdapter());
    await Hive.openBox<Agent>(agentBoxName);
    print('Hive initialized and agent box opened.');
  }

  static Box<Agent> getAgentBox() {
    return Hive.box<Agent>(agentBoxName);
  }

  static Future<void> addAgent(Agent agent) async {
    final box = getAgentBox();
    await box.add(agent);
  }

  static Future<void> deleteAgent(int index) async {
    final box = getAgentBox();
    await box.deleteAt(index);
    print('Agent at index $index deleted.');
  }

  // --- NEW FUNCTION TO CLEAR ALL AGENTS ---
  static Future<void> clearAllAgents() async {
    final box = getAgentBox();
    await box.clear();
    print('All agents have been cleared from the database.');
  }
}