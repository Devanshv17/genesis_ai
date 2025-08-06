// lib/downloader_screen.dart

// lib/downloader_screen.dart

import 'dart:io';
import 'home_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

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
  final Dio _dio = Dio();
  CancelToken _cancelToken = CancelToken();

  // We no longer need a hardcoded size here.
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

  @override
  void dispose() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel("Download cancelled because the screen was closed.");
    }
    super.dispose();
  }

  Future<String> getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$modelFilename';
  }

  Future<void> deleteModel() async {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel("Download cancelled by user deletion.");
    }
    final filePath = await getModelPath();
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
    // --- NEW: Also delete the saved model size preference ---
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('expectedModelSize');
    setState(() {
      isModelReady = false;
      downloadProgress = 0;
      statusText = 'Model not found. Please download.';
    });
  }

  // This check is now mostly for the UI of this screen, the main check is on the splash screen.
  Future<void> checkIfModelExists() async {
    final prefs = await SharedPreferences.getInstance();
    final expectedSize = prefs.getInt('expectedModelSize') ?? 0;
    final filePath = await getModelPath();
    final file = File(filePath);

    if (await file.exists() && expectedSize > 0) {
      final fileSize = await file.length();
      if (fileSize >= expectedSize) {
        setState(() {
          isModelReady = true;
          statusText = 'Model is ready.';
        });
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

    final savePath = await getModelPath();
    final tempPath = '$savePath.tmp';
    final tempFile = File(tempPath);
    int receivedBytes = 0;
    if (await tempFile.exists()) {
      receivedBytes = await tempFile.length();
    }

    setState(() {
      isLoading = true;
      statusText = 'Connecting...';
      _cancelToken = CancelToken();
    });

    try {
      await _dio.download(
        modelUrl,
        tempPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // --- NEW: Learn the total size from the download itself ---
            // The total reported by dio is the *full* size of the file.
            _totalBytes = total;
            setState(() {
              downloadProgress = received / total;
              statusText = 'Downloading... ${(downloadProgress * 100).toStringAsFixed(0)}%';
            });
          }
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $hfToken',
            'Range': 'bytes=$receivedBytes-',
          },
        ),
        deleteOnError: false,
      );

      await tempFile.rename(savePath);

      // --- NEW: Save the learned size for future app launches ---
      if (_totalBytes > 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('expectedModelSize', _totalBytes);
        print('SUCCESS: Saved expected model size: $_totalBytes bytes');
      }

      await modelManager.setModelPath(savePath);
      setState(() {
        isModelReady = true;
        isLoading = false;
        statusText = 'Model Ready! ✅';
      });

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        print("Download cancelled.");
        setState(() {
          isLoading = false;
          statusText = 'Download paused. Tap to resume.';
        });
      } else {
        setState(() {
          isLoading = false;
          statusText = 'Error: Check connection or token.';
        });
        print(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // The build method remains the same as the last version.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Genesis AI Setup'),
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
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: downloadProgress > 0 ? downloadProgress : null,
                    strokeWidth: 6,
                  ),
                )
              else
                const Icon(Icons.download_for_offline,
                    color: Colors.grey, size: 80),
              const SizedBox(height: 20),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, left: 16, right: 16),
                  child: Text(
                    'This is a large one-time download. You can pause and resume at any time.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 40),
              if (!isModelReady)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16)),
                  onPressed: isLoading
                      ? () => _cancelToken.cancel("User cancelled")
                      : downloadModel,
                  icon: Icon(isLoading ? Icons.pause_circle_filled : Icons.download_rounded),
                  label: Text(isLoading
                      ? 'Pause Download'
                      : statusText.contains('paused')
                      ? 'Resume Download'
                      : 'Download AI Model'),
                ),
              if (isModelReady)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                  child: const Text('Start Genesis AI'),
                )
            ],
          ),
        ),
      ),
    );
  }
}