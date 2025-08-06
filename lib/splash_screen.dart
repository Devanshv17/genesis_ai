// lib/splash_screen.dart

import 'dart:io';
import 'downloader_screen.dart';
import 'gemma_service.dart';
import 'home_screen.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // --- We no longer need a hardcoded size here. ---

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _checkModelAndNavigate);
  }

  // --- UPDATED: This function now reads the saved size for the check ---
  Future<void> _checkModelAndNavigate() async {
    // First, load the expected size that was saved after a successful download.
    final prefs = await SharedPreferences.getInstance();
    // Default to 0 if the size has never been saved before.
    final expectedSize = prefs.getInt('expectedModelSize') ?? 0;

    // If no size has ever been saved, we know the model doesn't exist.
    if (expectedSize == 0) {
      print('SplashScreen: No saved model size found. Navigating to downloader.');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DownloaderScreen()),
        );
      }
      return; // Stop here
    }

    final directory = await getApplicationDocumentsDirectory();
    const modelFilename = 'gemma-3n-E2B-it-int4.task';
    final filePath = '${directory.path}/$modelFilename';
    final file = File(filePath);

    bool modelIsValid = false;

    if (await file.exists()) {
      final fileSize = await file.length();
      // Compare the actual file size with the dynamically saved expected size.
      if (fileSize >= expectedSize) {
        print('SplashScreen: Model found and size is valid ($fileSize bytes).');
        modelIsValid = true;
      } else {
        print('SplashScreen: Model found but is incomplete ($fileSize bytes). Navigating to downloader.');
        modelIsValid = false;
      }
    } else {
      print('SplashScreen: Model not found. Navigating to downloader.');
      modelIsValid = false;
    }

    if (mounted) {
      if (modelIsValid) {
        await GemmaService.setupModelPath();
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
              'Initializing...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}