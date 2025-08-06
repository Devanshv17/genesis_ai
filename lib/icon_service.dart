// lib/icon_service.dart

import 'package:flutter/material.dart';

class IconService {
  // Our curated library of available icons for the agents.
  static final Map<String, IconData> iconMap = {
    // --- Original Icons ---
    'chat_bubble': Icons.chat_bubble_outline_rounded,
    'build_tool': Icons.build_circle_outlined,
    'cloud': Icons.cloud_outlined,
    'lightbulb': Icons.lightbulb_outline,
    'image': Icons.image_outlined,
    'psychology': Icons.psychology_outlined,
    'calculate': Icons.calculate_outlined,
    'code': Icons.code,
    'translate': Icons.translate,
    'palette': Icons.palette_outlined,
    'music_note': Icons.music_note_outlined,
    'menu_book': Icons.menu_book_outlined,
    'sports_esports': Icons.sports_esports_outlined,
    'movie': Icons.movie_outlined,
    'travel': Icons.explore_outlined,
    'history': Icons.history_edu_outlined,

    // --- ADD THESE NEW ICONS ---
    'self_improvement': Icons.self_improvement_outlined, // For Mindful Companion
    'visibility': Icons.visibility_outlined,          // For Visual Companion
    'school': Icons.school_outlined,                  // For ELI5 Assistant
    'auto_stories': Icons.auto_stories_outlined,      // For Story Starter
    'soup_kitchen': Icons.soup_kitchen_outlined,      // For Kitchen Assistant
    'fitness_center': Icons.fitness_center_outlined,  // For Fitness Coach
  };

  // A helper function to get an icon by its name, with a fallback.
  static IconData getIconByName(String name) {
    return iconMap[name] ?? Icons.smart_toy_outlined; // Default icon
  }
}