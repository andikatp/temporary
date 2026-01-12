import 'package:camera/camera.dart';
import 'package:face_auth_engine/face_auth_engine.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Singleton service to manage face detection and liveness models.
/// This allows models to be loaded once at app startup instead of per-screen.
class FaceModelService {
  FaceModelService._();
  static final FaceModelService instance = FaceModelService._();

  FaceDetector? _faceDetector;
  FaceAuthEngine? _engine;
  LivenessDetector?
  _liveness; // Ensure LivenessDetector is available in face_auth_engine or imports
  List<CameraDescription> _cameras = [];

  bool _isInitializing = false;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  FaceDetector? get faceDetector => _faceDetector;
  FaceAuthEngine? get engine => _engine;
  LivenessDetector? get liveness => _liveness;
  List<CameraDescription> get cameras => _cameras;

  /// Initializes all the heavy models.
  /// Call this at app startup or HomePage.
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;
    debugPrint('FaceModelService: Initializing models...');

    try {
      // 1. Initialize Liveness Detector
      // Assuming LivenessDetector is from face_auth_engine package based on context
      _liveness = await LivenessDetector.create(
        options: LivenessOptions(
          useGpu: true,
          threshold: 0.8,
          applyLaplacianGate: true,
          laplacianThreshold: 200,
        ),
      );

      // 2. Initialize Face Auth Engine
      _engine = FaceAuthEngine();

      // 3. Initialize Face Detector (ML Kit)
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(minFaceSize: 0.3),
      );

      // 4. Initialize Cameras (if not already cached)
      _cameras = await availableCameras();

      _isInitialized = true;
      debugPrint('FaceModelService: Models initialized successfully.');
    } catch (e, stackTrace) {
      debugPrint('FaceModelService: Error initializing models: $e');
      debugPrint(stackTrace.toString());
    } finally {
      _isInitializing = false;
    }
  }

  void dispose() {
    _faceDetector?.close();
    _isInitialized = false;
    // Handle other disposals if necessary
  }
}
