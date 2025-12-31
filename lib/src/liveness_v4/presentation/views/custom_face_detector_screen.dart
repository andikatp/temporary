import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_recognition/src/liveness_v4/others/camera_function.dart';
import 'package:face_recognition/src/liveness_v4/presentation/widgets/face_overlay.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CustomFaceDetectorScreen extends StatefulWidget {
  const CustomFaceDetectorScreen({super.key});

  @override
  State<CustomFaceDetectorScreen> createState() =>
      _CustomFaceDetectorScreenState();
}

class _CustomFaceDetectorScreenState extends State<CustomFaceDetectorScreen> {
  CameraController? _cameraController;
  late FaceDetector faceDetector;
  bool _isProcessingFrame = false;
  bool _isWellPositioned = false;
  List<CameraDescription> _cameras = [];

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    faceDetector = FaceDetector(options: FaceDetectorOptions(minFaceSize: 0.3));

    _cameras = await availableCameras();

    final controller = CameraController(
      _cameras.last,
      ResolutionPreset.high,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
      enableAudio: false,
    );

    await controller.initialize();
    await controller.setFlashMode(FlashMode.off);

    _cameraController = controller;

    await _startImageStream();

    if (!mounted) return;

    setState(() {
      _initialized = true;
    });
  }

  Future<void> _startImageStream() async {
    if (_cameraController?.value.isInitialized ?? false) {
      debugPrint('Camera is initialized');
      await _cameraController!.startImageStream(_processImage);
    }
  }

  Future<void> _stopImageStream() async {
    if (_cameraController!.value.isInitialized &&
        _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }
  }

  Future<void> _processImage(CameraImage cameraImage) async {
    if (_isProcessingFrame) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final conversionData = ImageConversionData(
        cameraImage,
        _cameras.length > 1
            ? _cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.front,
                orElse: () => _cameras.first,
              )
            : _cameras.first,
        _cameraController!.value.deviceOrientation,
      );

      final inputImage = CameraFunction.inputImageFromCameraImage(
        conversionData,
      );
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final faces = await faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final boundingBox = faces.first.boundingBox;
        final previewSize = _cameraController!.value.previewSize!;

        _isWellPositioned = CameraFunction.isFaceInCenter(
          boundingBox,
          previewSize,
        );
      } else {
        _isWellPositioned = false;
      }
    } catch (e) {
      _isWellPositioned = false;
    } finally {
      _isProcessingFrame = false;
      setState(() {});
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null) return;
  }

  @override
  void dispose() {
    _stopImageStream();

    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _cameraController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final controller = _cameraController!;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Transform.scale(
              scale:
                  1 /
                  (controller.value.aspectRatio *
                      MediaQuery.sizeOf(context).aspectRatio),
              child: CameraPreview(
                controller,
                child: FaceOverlay(isWellPositioned: _isWellPositioned),
              ),
            ),
          ),
          const Positioned(
            bottom: 280,
            left: 0,
            right: 0,
            child: Text(
              'Posisikan wajah anda di dalam oval',
              textAlign: .center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _takePicture,
                child: const Text('Test Liveness'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
