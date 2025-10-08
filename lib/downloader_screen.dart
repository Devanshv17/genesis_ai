import 'dart:io';
import 'home_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'env.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'llm_service.dart';

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
  final LlmService _llmService = getLlmService();

  int _totalBytes = 0;
  late final String modelFilename;
  late final String modelUrl;

  @override
  void initState() {
    super.initState();
    modelFilename = _llmService.getModelName();
    modelUrl = _llmService.getModelDownloadUrl();
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
      print("Model file deleted.");
    }
    final prefs = await SharedPreferences.getInstance();
    // Use a platform-specific key for the model size
    await prefs.remove('expectedModelSize_${Platform.operatingSystem}');

    setState(() {
      isModelReady = false;
      downloadProgress = 0;
      statusText = 'Model not found. Please download.';
    });
  }

  Future<void> checkIfModelExists() async {
    final prefs = await SharedPreferences.getInstance();
    final expectedSize = prefs.getInt('expectedModelSize_${Platform.operatingSystem}') ?? 0;
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
    final hfToken = Env.hfToken;
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
      final response = await _dio.get(
        modelUrl,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _totalBytes = total;
            setState(() {
              // We add the already downloaded bytes to the current received bytes
              downloadProgress = (received + receivedBytes) / (total + receivedBytes);
              statusText = 'Downloading... ${(downloadProgress * 100).toStringAsFixed(0)}%';
            });
          }
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $hfToken',
            'Range': 'bytes=$receivedBytes-',
          },
          responseType: ResponseType.stream, // Important for large files
        ),
      );

      final raf = tempFile.openSync(mode: FileMode.append);
      await for (final chunk in response.data.stream) {
        raf.writeFromSync(chunk);
      }
      await raf.close();

      await tempFile.rename(savePath);

      if (_totalBytes > 0) {
        final prefs = await SharedPreferences.getInstance();
        // Use a platform-specific key for saving the model size
        await prefs.setInt('expectedModelSize_${Platform.operatingSystem}', receivedBytes + _totalBytes);
        print('SUCCESS: Saved expected model size: ${receivedBytes + _totalBytes} bytes');
      }

      // --- REMOVED THE ERRONEOUS LINE HERE ---
      // No need to set model path, the service will handle it on next launch.

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
              const SizedBox(height: 8),
              Text(
                'Model for ${Platform.operatingSystem.toUpperCase()}:\n$modelFilename',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
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
                  icon: Icon(isLoading
                      ? Icons.pause_circle_filled
                      : Icons.download_rounded),
                  label: Text(isLoading
                      ? 'Pause Download'
                      : statusText.contains('paused')
                      ? 'Resume Download'
                      : 'Download AI Model'),
                ),
              if (isModelReady)
                ElevatedButton(
                  onPressed: () {
                    // Initialize the service before navigating away
                    _llmService.initialize().then((_) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()),
                      );
                    });
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