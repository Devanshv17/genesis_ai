import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'downloader_screen.dart';
import 'home_screen.dart';
import 'llm_service.dart'; // Import the new abstract service

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Get the correct LLM service implementation based on the current platform.
  final LlmService _llmService = getLlmService();

  @override
  void initState() {
    super.initState();
    // After a brief delay, check for the model and navigate.
    Future.delayed(const Duration(seconds: 2), _checkModelAndNavigate);
  }

  /// Checks if the platform-specific model file exists and is valid,
  /// then navigates to either the HomeScreen or DownloaderScreen.
  Future<void> _checkModelAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    // Use a platform-specific key to store the model size.
    // This allows different models for different platforms to coexist if needed.
    final expectedSize =
        prefs.getInt('expectedModelSize_${Platform.operatingSystem}') ?? 0;

    // If no size has ever been saved for this platform, go to downloader.
    if (expectedSize == 0) {
      print('SplashScreen: No saved model size found for ${Platform.operatingSystem}. Navigating to downloader.');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DownloaderScreen()),
        );
      }
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    // Get the model filename dynamically from the service.
    final modelFilename = _llmService.getModelName();
    final filePath = '${directory.path}/$modelFilename';
    final file = File(filePath);

    bool modelIsValid = false;

    if (await file.exists()) {
      final fileSize = await file.length();
      // Compare the actual file size with the saved expected size.
      if (fileSize >= expectedSize) {
        print(
            'SplashScreen: Model found for ${Platform.operatingSystem} and size is valid ($fileSize bytes).');
        modelIsValid = true;
      } else {
        print(
            'SplashScreen: Model found but is incomplete ($fileSize bytes). Navigating to downloader.');
      }
    } else {
      print('SplashScreen: Model not found. Navigating to downloader.');
    }

    if (mounted) {
      if (modelIsValid) {
        // Initialize the appropriate service before moving to the home screen.
        await _llmService.initialize();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DownloaderScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 120,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Initializing Genesis AI...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}