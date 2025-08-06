// lib/main.dart

import 'hive_service.dart';
import 'splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Your existing setup is correct and remains the same.
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await HiveService.initialize();
  runApp(const MyApp());
}

// --- NEW: DEFINING THE CLASSY COLOR THEME ---

// A deep, sophisticated blue for our primary "important" color.
const Color slateBlue = Color(0xFF2C3E50);
// A soft, off-white for a classier background than stark white.
const Color linen = Color(0xFFFDF6F0);

// Define the light theme data.
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: slateBlue,
    brightness: Brightness.light,
    background: linen, // Use linen for the main background
    surface: Colors.white, // Cards and dialogs can be a slightly brighter white
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: slateBlue,
    foregroundColor: Colors.white, // White title text on the app bar
  ),
  cardTheme: CardTheme(
    elevation: 2,
    surfaceTintColor: Colors.white, // Prevents cards from tinting on scroll
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
    ),
  ),
);

// Define the dark theme data for a consistent look in dark mode.
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: slateBlue,
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black,
  ),
  cardTheme: CardTheme(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
    ),
  ),
);


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Genesis AI',
      debugShowCheckedModeBanner: false, // Hides the debug banner
      // --- APPLYING THE THEME ---
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, // Automatically chooses based on device settings
      home: const SplashScreen(),
    );
  }
}