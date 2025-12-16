import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionResult {
  final List<FaceLandmark> landmarks;
  final Rect boundingBox;

  FaceDetectionResult({required this.landmarks, required this.boundingBox});
}

class FaceDetectorHelper {
  late FaceDetector _faceDetector;

  FaceDetectorHelper() {
    _initializeDetector();
  }

  void _initializeDetector() {
    final options = FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: false,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
  }

  /// Detects a single face in the image and returns landmarks and bounding box
  /// Throws an exception if:
  /// - No face is detected
  /// - Multiple faces are detected
  /// - Required landmarks are missing
  Future<FaceDetectionResult> detectFace(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      throw Exception(
        'No face detected. Please ensure:\n'
        '• Your face is clearly visible\n'
        '• Good lighting conditions\n'
        '• Face is frontal (not side profile)',
      );
    }

    if (faces.length > 1) {
      throw Exception(
        'Multiple faces detected (${faces.length} faces).\n'
        'Please ensure only one person is in the image.',
      );
    }

    final face = faces.first;

    // Extract required 5-point landmarks
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final noseTip = face.landmarks[FaceLandmarkType.noseBase];
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth];
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth];

    // Validate that all required landmarks are detected
    final missingLandmarks = <String>[];
    if (leftEye == null) missingLandmarks.add('left eye');
    if (rightEye == null) missingLandmarks.add('right eye');
    if (noseTip == null) missingLandmarks.add('nose');
    if (leftMouth == null) missingLandmarks.add('left mouth');
    if (rightMouth == null) missingLandmarks.add('right mouth');

    if (missingLandmarks.isNotEmpty) {
      throw Exception(
        'Face landmarks not detected: ${missingLandmarks.join(", ")}.\n'
        'Please use a clear frontal face photo.',
      );
    }

    log('Face detected successfully with all landmarks');
    log('Bounding box: ${face.boundingBox}');
    log('Left eye: ${leftEye!.position}');
    log('Right eye: ${rightEye!.position}');
    log('Nose: ${noseTip!.position}');
    log('Left mouth: ${leftMouth!.position}');
    log('Right mouth: ${rightMouth!.position}');

    return FaceDetectionResult(
      landmarks: [leftEye, rightEye, noseTip, leftMouth, rightMouth],
      boundingBox: face.boundingBox,
    );
  }

  void dispose() {
    _faceDetector.close();
  }
}
