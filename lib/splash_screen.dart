// lib/splash_screen.dart
import 'dart:io';
import 'downloader_screen.dart';
import 'gemma_service.dart';
import 'home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart'; // Add this import
import 'package:path_provider/path_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkModelAndNavigate();
  }

  Future<void> _checkModelAndNavigate() async {
    final directory = await getApplicationDocumentsDirectory();
    const modelFilename = 'gemma-3n-E2B-it-int4.task';
    final filePath = '${directory.path}/$modelFilename';
    final file = File(filePath);

    await Future.delayed(const Duration(seconds: 2));

    if (await file.exists()) {
      try {
        print('SplashScreen: Model found. Setting up GemmaService path...');
        // FIX: Call the renamed method from our previous correction.
        await GemmaService.setupModelPath();
        print('SplashScreen: Service path configured. Navigating to HomeScreen.');

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } catch (e) {
        // This catch block might now be less likely to trigger,
        // but it's good for safety.
        print('SplashScreen: Error during path setup: $e. Navigating to DownloaderScreen.');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DownloaderScreen()),
        );
      }
    } else {
      print('SplashScreen: Model not found, navigating to DownloaderScreen.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DownloaderScreen()),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Checking for AI model...'),
          ],
        ),
      ),
    );
  }
}