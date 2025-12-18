import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class MLHelper {
  MLHelper._();
  static final MLHelper instance = MLHelper._();

  final FaceDetector detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: .fast,
    ),
  );

  static InputImage? buildInputImage(CameraImage image) {
    final rotation = InputImageRotationValue.fromRawValue(270);
    if (rotation == null) return null;

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: .nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<List<Face>> processInputImage(InputImage image) {
    return detector.processImage(image);
  }
}
