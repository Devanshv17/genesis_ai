import 'dart:io';
import 'home_screen.dart'; // Import the HomeScreen
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  bool isLoading = false;
  double downloadProgress = 0;
  bool isModelReady = false;
  String statusText = 'Checking model status...';

  int _receivedBytes = 0;
  int _totalBytes = 0;

  final modelManager = FlutterGemmaPlugin.instance.modelManager;
  static const modelFilename = 'gemma-3n-E2B-it-int4.task';
  static const modelUrl =
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/$modelFilename?download=true';


  @override
  void initState() {
    super.initState();
    checkIfModelExists();
  }

  Future<String> getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$modelFilename';
  }

  Future<void> deleteModel() async {
    final filePath = await getModelPath();
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
    setState(() {
      isModelReady = false;
      statusText = 'Model not found. Please download.';
      _receivedBytes = 0;
      _totalBytes = 0;
    });
  }

  Future<void> checkIfModelExists() async {
    final filePath = await getModelPath();
    final file = File(filePath);
    if (await file.exists()) {
      try {
        await modelManager.setModelPath(filePath);
        setState(() {
          isModelReady = true;
          statusText = 'Model is ready.';
        });
      } catch (e) {
        print("Model file exists but is corrupt. Deleting...");
        await deleteModel();
      }
    } else {
      setState(() {
        statusText = 'Model not found. Please download.';
      });
    }
  }

  Future<void> downloadModel() async {
    final hfToken = dotenv.env['HF_TOKEN'] ?? '';
    if (hfToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Hugging Face token not found in .env file!'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      isLoading = true;
      downloadProgress = 0;
      _receivedBytes = 0;
      _totalBytes = 0;
      statusText = 'Connecting...';
    });

    final dio = Dio();
    final savePath = await getModelPath();

    try {
      await dio.download(
        modelUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
              downloadProgress = received / total;
              statusText =
              'Downloading... ${(downloadProgress * 100).toStringAsFixed(0)}%';
            });
          }
        },
        options: Options(
          headers: {'Authorization': 'Bearer $hfToken'},
        ),
      );

      await modelManager.setModelPath(savePath);
      setState(() {
        isModelReady = true;
        isLoading = false;
        statusText = 'Model Ready! ✅';
      });

      // --- ADDED NAVIGATION ---
      // After a successful download, navigate to the HomeScreen
      if (mounted) { // Check if the widget is still in the tree
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }

    } catch (e) {
      setState(() {
        isLoading = false;
        statusText = 'Error: Check connection or token.';
      });
      print(e);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 MB";
    return (bytes / (1024 * 1024)).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Agent Setup'),
        actions: [
          if (isModelReady)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Reset Model',
              onPressed: deleteModel,
            )
        ],
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (isModelReady)
                const Icon(Icons.check_circle, color: Colors.green, size: 80)
              else if (isLoading)
                CircularProgressIndicator(value: downloadProgress)
              else
                const Icon(Icons.download_for_offline,
                    color: Colors.grey, size: 80),
              const SizedBox(height: 20),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              // --- ADDED INSTRUCTIONAL TEXT ---
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, left: 16, right: 16),
                  child: Text(
                    'This is a large one-time download. Please keep the app open and on a stable Wi-Fi connection.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),

              if (isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    '${_formatBytes(_receivedBytes)} MB / ${_formatBytes(_totalBytes)} MB',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),

              const SizedBox(height: 40),
              if (!isModelReady && !isLoading)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16)),
                  onPressed: downloadModel,
                  child: const Text('Download AI Model (~3.1 GB)'),
                ),
              if (isModelReady)
                ElevatedButton(
                  onPressed: () {
                    // This button is now a fallback, in case the user
                    // already has the model from a previous session.
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                  child: const Text('Go to Home'),
                )
            ],
          ),
        ),
      ),
    );
  }
}