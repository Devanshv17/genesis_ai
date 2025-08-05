// lib/gemma_service.dart
import 'dart:io';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

class GemmaService {
  // This will hold our single, shared model instance.
  static InferenceModel? model;

  // This function will be called once when the app starts.
  static Future<void> initialize() async {
    final modelManager = FlutterGemmaPlugin.instance.modelManager;
    final directory = await getApplicationDocumentsDirectory();
    const modelFilename = 'gemma-3n-E2B-it-int4.task';
    final filePath = '${directory.path}/$modelFilename';

    // Set the path so the plugin knows where the model is.
    await modelManager.setModelPath(filePath);

    // Create the single instance of the model.
    model = await FlutterGemmaPlugin.instance.createModel(
      modelType: ModelType.gemmaIt,
      supportImage: true,
    );
    print('GemmaService: Shared InferenceModel created successfully.');
  }
}