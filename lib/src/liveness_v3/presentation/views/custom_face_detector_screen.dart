import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_recognition/src/liveness_v3/presentation/widgets/circular_progress_widget/circular_progress_widget.dart';
import 'package:face_recognition/src/liveness_v3/presentation/widgets/face_overlay.dart';
import 'package:flutter/material.dart';

class CustomFaceDetectorScreen extends StatefulWidget {
  const CustomFaceDetectorScreen({super.key});

  @override
  State<CustomFaceDetectorScreen> createState() =>
      _CustomFaceDetectorScreenState();
}

class _CustomFaceDetectorScreenState extends State<CustomFaceDetectorScreen> {
  CameraController? _cameraController;
  late CircularProgressWidget _circularProgressWidget;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _circularProgressWidget = CircularProgressWidget(
      unselectedColor: Colors.grey,
      selectedColor: Colors.green,
      heightLine: 25,
      current: 0,
      maxStep: 100,
      child: const SizedBox.shrink(),
    );
    final cameras = await availableCameras();

    final controller = CameraController(
      cameras.last,
      ResolutionPreset.high,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
      enableAudio: false,
    );

    await controller.initialize();
    await controller.setFlashMode(FlashMode.off);

    if (!mounted) return;

    setState(() {
      _cameraController = controller;
      _initialized = true;
    });
  }

  Future<void> _takePicture() async {
    if (_cameraController == null) return;
  }

  @override
  void dispose() {
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
                child: FaceOverlay(isWellPositioned: true),
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
