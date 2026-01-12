import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_auth_engine/face_auth_engine.dart';
import 'package:face_recognition/services/face_model_service.dart';
import 'package:face_recognition/src/liveness_v4/others/camera_function.dart';
import 'package:face_recognition/src/liveness_v4/presentation/widgets/face_overlay.dart';
import 'package:face_recognition/util/face_database.dart';
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
  late final LivenessDetector liveness;
  late final FaceAuthEngine engine;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Ensure models are initialized
    final service = FaceModelService.instance;
    await service.initialize(); // Safe to call multiple times

    liveness = service.liveness!;
    engine = service.engine!;
    faceDetector = service.faceDetector!;
    _cameras = service.cameras;

    final frontCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    final controller = CameraController(
      frontCamera,
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
    try {
      if (_cameraController == null) return;
      if (_cameraController!.value.isTakingPicture) return;

      final result = await _cameraController!.takePicture();
      final imageFile = File(result.path);

      final resultLiveness = await liveness.detectLiveness(imageFile);

      final users = await LocalUserEmbeddingRepo().loadUsers();

      UserEmbedded? matchedUser;

      for (final user in users) {
        final isMatch = await engine.matchFaceAgainstList(
          imageFile.path,
          user.embeddings,
        );

        if (isMatch) {
          matchedUser = user;
          break;
        }
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Liveness Result'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Is Live: ${resultLiveness.isLive}'),
                Text('Score: ${resultLiveness.score}'),
                Text('Laplacian: ${resultLiveness.laplacian}'),
                Text(
                  matchedUser != null
                      ? 'User exist: ${matchedUser.name}'
                      : 'User not recognized',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _stopImageStream();
    // Do not close faceDetector as it is shared via FaceModelService
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
                child: FaceOverlay(
                  isWellPositioned: _isWellPositioned,
                  showProgress: false,
                ),
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
