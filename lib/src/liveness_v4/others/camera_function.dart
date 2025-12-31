import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_recognition/src/liveness_v4/others/nv21_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

class CameraFunction {
  CameraFunction._();
  static final _toleranceX = Platform.isAndroid ? 330.0 : 850.0;
  static final _toleranceY = Platform.isAndroid ? 160.0 : 395.0;

  static bool isFaceInCenter(Rect boundingBox, Size previewSize) {
    try {
      final centerX = previewSize.width / 2;
      final centerY = previewSize.height / 2;

      final faceCenterX = boundingBox.left + boundingBox.width / 2;
      final faceCenterY = boundingBox.top + boundingBox.height / 2;

      final distanceX = (faceCenterX - centerX).abs();
      final distanceY = (faceCenterY - centerY).abs();

      debugPrint('distanceX: $distanceX, distanceY: $distanceY');
      debugPrint('toleranceX: $_toleranceX, toleranceY: $_toleranceY');

      return distanceX < _toleranceX && distanceY < _toleranceY;
    } catch (e, s) {
      debugPrint('Error in isFaceInCenter: $e');
      debugPrint('Stack trace: $s');
      return false;
    }
  }

  static final Map<int, InputImageRotation?> _rotationCache = {};

  static InputImage? inputImageFromCameraImage(ImageConversionData data) {
    final sensorOrientation = data.cameraDescription.sensorOrientation;
    InputImageRotation? rotation;
    InputImageFormat? format;

    if (Platform.isIOS) {
      rotation =
          _rotationCache[sensorOrientation] ??
          InputImageRotationValue.fromRawValue(sensorOrientation);
      if (_rotationCache[sensorOrientation] == null) {
        _rotationCache[sensorOrientation] = rotation;
      }
      format = InputImageFormat.bgra8888;
    } else if (Platform.isAndroid) {
      final rotationCompensation = _orientations[data.deviceOrientation];
      if (rotationCompensation == null) return null;

      int finalRotation;
      if (data.cameraDescription.lensDirection == CameraLensDirection.front) {
        finalRotation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        finalRotation = (sensorOrientation - rotationCompensation + 360) % 360;
      }

      rotation =
          _rotationCache[finalRotation] ??
          InputImageRotationValue.fromRawValue(finalRotation);
      if (_rotationCache[finalRotation] == null) {
        _rotationCache[finalRotation] = rotation;
      }
      format = InputImageFormat.nv21;
    }

    if (rotation == null || format == null) return null;

    late Uint8List bytes;
    if (Platform.isAndroid) {
      if (data.image.planes.length == 1) {
        bytes = data.image.planes[0].bytes;
      } else {
        bytes = data.image.getNv21Uint8List();
      }
    } else {
      bytes = data.image.planes[0].bytes;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(data.image.width.toDouble(), data.image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: data.image.planes[0].bytesPerRow,
      ),
    );
  }

  static Future<bool> checkIsUserAlone({
    required String path,
    required FaceDetector faceDetector,
    required Future<void> Function() additional,
  }) async {
    final inputImage = InputImage.fromFilePath(path);

    final faces = await faceDetector
        .processImage(inputImage)
        .timeout(const Duration(seconds: 5), onTimeout: () => []);

    if (faces.length > 1) {
      throw Exception(
        'Maaf, kami mendeteksi lebih dari satu wajah. Fitur ini hanya '
        'dapat digunakan untuk satu orang pada satu waktu. Coba ubah '
        'posisi Anda atau minta orang lain untuk menjauh dari kamera.',
      );
    }
    return true;
  }

  static final Map<String, File> _assetFileCache = {};

  static Future<File> getTemporaryFileFromAsset(String assetPath) async {
    if (_assetFileCache.containsKey(assetPath)) {
      final cachedFile = _assetFileCache[assetPath]!;
      if (cachedFile.existsSync()) {
        return cachedFile;
      }
    }

    final directory = await getTemporaryDirectory();

    final fileName = assetPath.split('/').last;
    final tempFilePath = '${directory.path}/$fileName';

    final byteData = await rootBundle.load(assetPath);

    final file = File(tempFilePath);
    await file.writeAsBytes(byteData.buffer.asUint8List());

    _assetFileCache[assetPath] = file;

    return file;
  }

  static Future<double> getImageFileSize(File file) async {
    final fileSizeInBytes = await file.length();
    final fileSizeInKB = fileSizeInBytes / 1024;
    return double.parse(fileSizeInKB.toStringAsFixed(2));
  }
}

const Map<DeviceOrientation, int> _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

class ImageConversionData {
  const ImageConversionData(
    this.image,
    this.cameraDescription,
    this.deviceOrientation,
  );

  final CameraImage image;
  final CameraDescription cameraDescription;
  final DeviceOrientation deviceOrientation;
}

class SerializableInputImageData {
  const SerializableInputImageData({
    required this.bytes,
    required this.width,
    required this.height,
    required this.inputImageFormat,
    required this.inputImageRotation,
  });
  final Uint8List bytes;
  final int width;
  final int height;
  final InputImageFormat inputImageFormat;
  final InputImageRotation inputImageRotation;
}
