import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:collection/collection.dart';
import 'package:face_recognition/src/liveness_v3/core/index.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class LivenessFaceProcessor {
  bool isBusy = false;

  Future<List<Face>> processImage(
    CameraImage cameraImage,
    int sensorOrientation,
  ) async {
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return [];

    final inputImage = InputImage.fromBytes(
      bytes: cameraImage.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      ),
    );

    return await MachineLearningKitHelper.instance.processInputImage(
      inputImage,
    );
  }

  bool detectBlink(Face face, List<LivenessDetectionThreshold> thresholds) {
    final blinkThreshold =
        thresholds.firstWhereOrNull((p0) => p0 is LivenessThresholdBlink)
            as LivenessThresholdBlink?;

    return (face.leftEyeOpenProbability ?? 1.0) <
            (blinkThreshold?.leftEyeProbability ?? 0.25) &&
        (face.rightEyeOpenProbability ?? 1.0) <
            (blinkThreshold?.rightEyeProbability ?? 0.25);
  }

  bool detectTurnRight(Face face, List<LivenessDetectionThreshold> thresholds) {
    final headTurnThreshold =
        thresholds.firstWhereOrNull((p0) => p0 is LivenessThresholdHead)
            as LivenessThresholdHead?;

    if (Platform.isAndroid) {
      return (face.headEulerAngleY ?? 0) <
          (headTurnThreshold?.rotationAngle ?? -30);
    } else if (Platform.isIOS) {
      return (face.headEulerAngleY ?? 0) >
          (headTurnThreshold?.rotationAngle ?? 30);
    }
    return false;
  }

  bool detectTurnLeft(Face face, List<LivenessDetectionThreshold> thresholds) {
    final headTurnThreshold =
        thresholds.firstWhereOrNull((p0) => p0 is LivenessThresholdHead)
            as LivenessThresholdHead?;

    if (Platform.isAndroid) {
      return (face.headEulerAngleY ?? 0) >
          (headTurnThreshold?.rotationAngle ?? 30);
    } else if (Platform.isIOS) {
      return (face.headEulerAngleY ?? 0) <
          (headTurnThreshold?.rotationAngle ?? -30);
    }
    return false;
  }

  bool detectLookUp(Face face, List<LivenessDetectionThreshold> thresholds) {
    final headTurnThreshold =
        thresholds.firstWhereOrNull((p0) => p0 is LivenessThresholdHead)
            as LivenessThresholdHead?;
    return (face.headEulerAngleX ?? 0) >
        (headTurnThreshold?.rotationAngle ?? 20);
  }

  bool detectLookDown(Face face, List<LivenessDetectionThreshold> thresholds) {
    final headTurnThreshold =
        thresholds.firstWhereOrNull((p0) => p0 is LivenessThresholdHead)
            as LivenessThresholdHead?;
    return (face.headEulerAngleX ?? 0) <
        (headTurnThreshold?.rotationAngle ?? -15);
  }

  bool detectSmile(Face face, List<LivenessDetectionThreshold> thresholds) {
    final smileThreshold =
        thresholds.firstWhereOrNull((p0) => p0 is LivenessThresholdSmile)
            as LivenessThresholdSmile?;

    return (face.smilingProbability ?? 0) >
        (smileThreshold?.probability ?? 0.65);
  }
}
