import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_recognition/src/liveness_v3/core/utils/image_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class LivenessCameraController {
  CameraController? _cameraController;
  int _cameraIndex = 0;
  List<CameraDescription> _availableCams = [];

  CameraController? get controller => _cameraController;
  bool get isInitialized => _cameraController?.value.isInitialized ?? false;

  Future<void> initialize() async {
    _availableCams = await availableCameras();
    if (_availableCams.isEmpty) return;

    if (_availableCams.any(
      (element) =>
          element.lensDirection == CameraLensDirection.front &&
          element.sensorOrientation == 90,
    )) {
      _cameraIndex = _availableCams.indexOf(
        _availableCams.firstWhere(
          (element) =>
              element.lensDirection == CameraLensDirection.front &&
              element.sensorOrientation == 90,
        ),
      );
    } else {
      _cameraIndex = _availableCams.indexOf(
        _availableCams.firstWhere(
          (element) => element.lensDirection == CameraLensDirection.front,
          orElse: () => _availableCams.first,
        ),
      );
    }
  }

  Future<void> startLiveFeed({
    required Function(CameraImage) onImage,
    required ResolutionPreset resolution,
  }) async {
    if (_availableCams.isEmpty) return;

    final camera = _availableCams[_cameraIndex];
    _cameraController = CameraController(
      camera,
      resolution,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    await _cameraController!.startImageStream(onImage);
  }

  Future<void> stopImageStream() async {
    if (_cameraController?.value.isStreamingImages == true) {
      await _cameraController?.stopImageStream();
    }
  }

  Future<XFile?> takePicture({required int imageQuality}) async {
    if (_cameraController == null) return null;

    try {
      await stopImageStream();
      final XFile? clickedImage = await _cameraController?.takePicture();
      if (clickedImage == null) return null;

      return await _compressImage(clickedImage, quality: imageQuality);
    } catch (e) {
      debugPrint('Error taking picture: $e');
      return null;
    }
  }

  Future<File?> captureFromStream({
    required CameraImage image,
    required int quality,
  }) async {
    try {
      final camera = _availableCams[_cameraIndex];

      final bytes = await compute(ImageHelper.processCameraImage, {
        'cameraImage': image,
        'quality': quality,
        'rotation': camera.sensorOrientation,
        'isFrontCamera': camera.lensDirection == CameraLensDirection.front,
      });

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  Future<XFile?> _compressImage(
    XFile originalFile, {
    required int quality,
  }) async {
    if (quality >= 100) {
      return originalFile;
    }

    try {
      final bytes = await originalFile.readAsBytes();

      final img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        return originalFile;
      }

      final tempDir = await getTemporaryDirectory();
      final String targetPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final compressedBytes = img.encodeJpg(originalImage, quality: quality);

      final File compressedFile = await File(
        targetPath,
      ).writeAsBytes(compressedBytes);

      return XFile(compressedFile.path);
    } catch (e) {
      debugPrint("Error compressing image: $e");
      return originalFile;
    }
  }

  CameraDescription get currentCamera => _availableCams[_cameraIndex];

  void dispose() {
    _cameraController?.dispose();
  }
}
