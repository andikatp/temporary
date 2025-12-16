import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:face_recognition/util/face_alignment_helper.dart';
import 'package:face_recognition/util/face_detector_helper.dart';
import 'package:face_recognition/util/sqlite_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../model/face_model.dart';

class FaceRecognitionModel extends ChangeNotifier {
  final String modelName = 'assets/models/mobilefacenet.tflite';
  Interpreter? _interpreter;
  FaceDetectorHelper? _faceDetector;
  double threshold = 1.0; // Updated threshold for L2-normalized embeddings
  List<FaceModel> knownFaces = [];
  SqliteHelper sqliteHelper = SqliteHelper();
  String? loadingMessage;
  String? personDetected;

  FaceRecognitionModel() {
    loadModel();
    _faceDetector = FaceDetectorHelper();
  }

  @override
  void dispose() {
    _interpreter?.close();
    _faceDetector?.dispose();
    super.dispose();
  }

  void setLoadingMessage(String? value) {
    loadingMessage = value;
    notifyListeners();
  }

  // Load the TensorFlow Lite model ONCE and reuse it
  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(modelName);
    knownFaces = await sqliteHelper.readAll();
    List<int>? inputShape = _interpreter!.getInputTensor(0).shape;
    TensorType inputType = _interpreter!.getInputTensor(0).type;
    List<int>? outputShape = _interpreter!.getOutputTensor(0).shape;
    TensorType outputType = _interpreter!.getOutputTensor(0).type;
    notifyListeners();
    log("Model loaded successfully");
    log("Model Input Shape: $inputShape");
    log("Model Input Type: $inputType");
    log("Model Output Shape: $outputShape");
    log("Model Output Type: $outputType");
  }

  Future<void> saveImage(String name, ImageSource source) async {
    personDetected = null;
    setLoadingMessage("Detecting and processing face\nPlease wait...");
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? imageFile = await picker.pickImage(source: source);
      if (imageFile != null) {
        final Float32List processedImage = await preprocessImage(imageFile);
        final Float32List? outputVector = await runModel(processedImage);
        if (outputVector != null) {
          FaceModel faceModel = FaceModel(name: name, faceData: outputVector);
          await sqliteHelper.add(faceModel);
          knownFaces.add(faceModel);
          log('Face saved successfully for: $name');
        }
      }
      var list = await sqliteHelper.readAll();
      log(list.toString());
    } catch (e) {
      log('Error saving face: $e');
      setLoadingMessage('Error: $e');
      await Future.delayed(const Duration(seconds: 3));
    }
    setLoadingMessage(null);
  }

  Future<void> deleteAllData() async {
    setLoadingMessage("Deleting data...Please wait");
    personDetected = null;
    await sqliteHelper.clear();
    setLoadingMessage(null);
  }

  // Pick image from camera or gallery and process it
  Future<void> processImage(ImageSource source) async {
    personDetected = null;
    setLoadingMessage("Detecting and processing face\nPlease wait...");
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? imageFile = await picker.pickImage(source: source);
      if (imageFile != null) {
        final Float32List processedImage = await preprocessImage(imageFile);
        final Float32List? outputVector = await runModel(processedImage);
        if (outputVector != null) {
          personDetected = recognizeFace(outputVector, knownFaces, threshold);
          log('Recognition result: $personDetected');
        }
      }
    } catch (e) {
      log('Error processing image: $e');
      personDetected = 'Error: $e';
    }
    setLoadingMessage(null);
    notifyListeners();
  }

  Future<Float32List> preprocessImage(XFile imageFile) async {
    final File file = File(imageFile.path);
    final Uint8List imageBytes = await file.readAsBytes();

    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) throw Exception("Failed to decode image.");

    // Step 1: Detect face and extract landmarks
    if (_faceDetector == null) {
      throw Exception("Face detector not initialized");
    }
    final faceResult = await _faceDetector!.detectFace(file);

    if (!isFaceAcceptable(
      boundingBox: faceResult.boundingBox,
      landmarks: faceResult.landmarks,
    )) {
      throw Exception('Face quality too low. Please face the camera.');
    }

    // Step 2: Align face using detected landmarks
    log('Aligning face using detected landmarks...');
    final alignedFace = FaceAlignmentHelper.alignFace(
      originalImage,
      faceResult.landmarks,
    );

    // Step 3: Normalize to [-1, 1] (correct for MobileFaceNet)
    Float32List inputImage = Float32List(112 * 112 * 3);
    int pixelIndex = 0;

    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        img.Pixel pixel = alignedFace.getPixel(x, y);
        // Correct normalization: (pixel - 127.5) / 128.0 → range [-1, 1]
        inputImage[pixelIndex++] = (pixel.r.toInt() - 127.5) / 128.0;
        inputImage[pixelIndex++] = (pixel.g.toInt() - 127.5) / 128.0;
        inputImage[pixelIndex++] = (pixel.b.toInt() - 127.5) / 128.0;
      }
    }

    return inputImage;
  }

  Float32List normalizeEmbedding(Float32List embedding) {
    double norm = math.sqrt(embedding.fold(0.0, (sum, val) => sum + val * val));
    return Float32List.fromList(embedding.map((val) => val / norm).toList());
  }

  Future<Float32List?> runModel(Float32List inputImage) async {
    try {
      // FIXED: Reuse interpreter instead of recreating
      if (_interpreter == null) {
        log('Interpreter not loaded, loading now...');
        await loadModel();
      }

      if (_interpreter == null) {
        log('Failed to load interpreter');
        return null;
      }

      var input = inputImage.reshape([1, 112, 112, 3]);
      var output = List.filled(1 * 192, 0.0).reshape([1, 192]);
      _interpreter!.run(input, output);
      Float32List outputList = Float32List.fromList(
        output.expand<double>((e) => e).toList(),
      );
      Float32List normalizedOutput = normalizeEmbedding(outputList);
      log(
        'Generated embedding, first 5 values: ${normalizedOutput.sublist(0, 5)}',
      );
      return normalizedOutput;
    } catch (e, stackTrace) {
      log("Error running model: $e");
      log("Stack trace: $stackTrace");
    }
    return null;
  }

  double euclideanDistance(List<double> vector1, List<double> vector2) {
    double sum = 0.0;
    for (int i = 0; i < vector1.length; i++) {
      sum += (vector1[i] - vector2[i]) * (vector1[i] - vector2[i]);
    }
    return math.sqrt(sum);
  }

  String recognizeFace(
    List<double> query,
    List<FaceModel> knownFaces,
    double threshold,
  ) {
    final Map<String, double> bestDistances = {};

    for (final face in knownFaces) {
      final d = euclideanDistance(query, face.faceData!);

      bestDistances.update(
        face.name!,
        (old) => math.min(old, d),
        ifAbsent: () => d,
      );
    }

    String result = "Unknown";
    double minDist = double.infinity;

    bestDistances.forEach((name, dist) {
      if (dist < minDist && dist < threshold) {
        minDist = dist;
        result = name;
      }
    });

    return result;
  }

  bool isFaceAcceptable({
    required Rect boundingBox,
    required List<FaceLandmark> landmarks,
  }) {
    // 1. Face size check
    if (boundingBox.width < 80 || boundingBox.height < 80) {
      return false;
    }

    // 2. Required landmarks check
    final types = landmarks.map((l) => l.type).toSet();
    const required = {
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
    };

    if (!types.containsAll(required)) {
      return false;
    }

    // 3. Eye-line tilt check (head roll approximation)
    final leftEye = landmarks
        .firstWhere((l) => l.type == FaceLandmarkType.leftEye)
        .position;
    final rightEye = landmarks
        .firstWhere((l) => l.type == FaceLandmarkType.rightEye)
        .position;

    final dx = rightEye.x - leftEye.x;
    final dy = rightEye.y - leftEye.y;

    final rollAngle = math.atan2(dy, dx) * 180 / math.pi;

    if (rollAngle.abs() > 15) {
      return false;
    }

    return true;
  }
}
