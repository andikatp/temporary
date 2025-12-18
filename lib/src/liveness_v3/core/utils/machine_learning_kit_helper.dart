import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class MachineLearningKitHelper {
  MachineLearningKitHelper._();
  static final instance = MachineLearningKitHelper._();

  final FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: .accurate,
    ),
  );

  Future<List<Face>> processInputImage(InputImage image) async {
    try {
      return await faceDetector.processImage(image);
    } catch (e) {
      debugPrint('MLKit error: $e');
      return [];
    }
  }
}
