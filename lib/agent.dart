import 'package:ai_agent/icon_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:hive/hive.dart';

part 'agent.g.dart';

@HiveType(typeId: 0)
class Agent extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late String persona;

  @HiveField(2)
  late List<String> toolNames;

  // --- NEW FIELD TO STORE THE ICON NAME ---
  @HiveField(3)
  late String iconName;

  // Helper to get the actual Tool objects at runtime
  List<gemma.Tool> get tools {
    List<gemma.Tool> toolObjects = [];
    if (toolNames.contains('toggle_flashlight')) {
      toolObjects.add(const gemma.Tool(
          name: 'toggle_flashlight',
          description: "Turns the device's flashlight on or off.",
          parameters: { 'type': 'object', 'properties': { 'isOn': {'type': 'boolean', 'description': 'Set to true to turn the flashlight on, false to turn it off.'}}, 'required': ['isOn']}));
    }
    if (toolNames.contains('get_current_weather')) {
      toolObjects.add(const gemma.Tool(
          name: 'get_current_weather',
          description: "Gets the current weather for a specified location.",
          parameters: {'type': 'object', 'properties': {'location': {'type': 'string', 'description': 'The city and state, or city and country, e.g., San Francisco, CA or London, UK'}},'required': ['location']}));
    }
    return toolObjects;
  }

  // --- NEW HELPER TO GET THE ICONDATA OBJECT ---
  IconData get iconData => IconService.getIconByName(iconName);
}
