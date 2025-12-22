// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_recognition/src/liveness_v3/core/constants/index.dart';
import 'package:face_recognition/src/liveness_v3/core/index.dart';
import 'package:face_recognition/src/liveness_v3/domain/liveness_steps.dart';
import 'package:face_recognition/src/liveness_v3/flutter_liveness_detection_randomized_plugin.dart';
import 'package:face_recognition/src/liveness_v3/presentation/liveness_camera_controller.dart';
import 'package:face_recognition/src/liveness_v3/presentation/liveness_detection_coordinator.dart';
import 'package:face_recognition/src/liveness_v3/presentation/liveness_face_processor.dart';
import 'package:face_recognition/src/liveness_v3/utils/brightness_helper.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class LivenessDetectionScreen extends StatefulWidget {
  final LivenessDetectionConfig config;

  const LivenessDetectionScreen({super.key, required this.config});

  @override
  State<LivenessDetectionScreen> createState() =>
      _LivenessDetectionScreenState();
}

class _LivenessDetectionScreenState extends State<LivenessDetectionScreen> {
  // Controllers
  final LivenessCameraController _cameraController = LivenessCameraController();
  final LivenessFaceProcessor _faceProcessor = LivenessFaceProcessor();
  late final LivenessDetectionCoordinator _coordinator;

  // Detection state variables
  late bool _isInfoStepCompleted;
  bool _faceDetectedState = false;
  List<LivenessDetectionStepItem> _shuffledSteps = [];
  bool _isCapturingStepImage = false;
  int _lastCapturedStepIndex = -1;

  final List<File> _capturedImages = [];
  Timer? _timerToDetectFace;
  CameraImage? _latestFrame;
  bool _isTakingPicture = false;

  @override
  void initState() {
    _initializeShuffledSteps();
    _coordinator = LivenessDetectionCoordinator(
      totalSteps: _shuffledSteps.length,
    );
    _preInitCallBack();
    super.initState();
    if (widget.config.enableCooldownOnFailure) {
      LivenessCooldownService.instance.configure(
        maxFailedAttempts: widget.config.maxFailedAttempts,
        cooldownMinutes: widget.config.cooldownMinutes,
      );
      LivenessCooldownService.instance.initializeCooldownTimer();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _postFrameCallBack());
  }

  @override
  void dispose() {
    _coordinator.dispose();
    _timerToDetectFace?.cancel();
    _timerToDetectFace = null;
    _cameraController.dispose();

    if (widget.config.isEnableMaxBrightness) {
      BrightnessHelper.resetApplicationBrightness();
    }
    super.dispose();
  }

  void _preInitCallBack() {
    _capturedImages.clear();
    _isInfoStepCompleted = !widget.config.startWithInfoScreen;

    if (widget.config.isEnableMaxBrightness) {
      BrightnessHelper.setApplicationBrightness(1.0);
    }
  }

  void _postFrameCallBack() async {
    await _cameraController.initialize();
    if (!widget.config.startWithInfoScreen) {
      _startLiveFeed();
    }
  }

  void _startLiveFeed() async {
    await _cameraController.startLiveFeed(
      onImage: _processCameraImage,
      resolution: widget.config.cameraResolution,
    );
    if (mounted) setState(() {});
    _startFaceDetectionTimer();
  }

  void _startFaceDetectionTimer() {
    _timerToDetectFace = Timer(
      Duration(seconds: widget.config.durationLivenessVerify ?? 45),
      () => _onDetectionCompleted(imgToReturn: null),
    );
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    _latestFrame = cameraImage;

    if (_faceProcessor.isBusy) return;
    _faceProcessor.isBusy = true;

    final faces = await _faceProcessor.processImage(
      cameraImage,
      _cameraController.currentCamera.sensorOrientation,
    );

    if (faces.isEmpty) {
      _resetSteps();
      if (mounted) setState(() => _faceDetectedState = false);
    } else {
      if (mounted) setState(() => _faceDetectedState = true);
      final currentIndex = _coordinator.currentIndex;
      if (currentIndex < _shuffledSteps.length) {
        await _detectFace(
          face: faces.first,
          step: _shuffledSteps[currentIndex].step,
        );
      }
    }

    _faceProcessor.isBusy = false;
    if (mounted) setState(() {});
  }

  Future<void> _detectFace({
    required Face face,
    required LivenessDetectionStep step,
  }) async {
    debugPrint('Current Step: $step');

    final thresholds =
        FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig;

    bool stepCompleted = false;

    switch (step) {
      case .blink:
        stepCompleted = _faceProcessor.detectBlink(face, thresholds);
        break;
      case .lookRight:
        stepCompleted = _faceProcessor.detectTurnRight(face, thresholds);
        break;
      case .lookLeft:
        stepCompleted = _faceProcessor.detectTurnLeft(face, thresholds);
        break;
      case .lookUp:
        stepCompleted = _faceProcessor.detectLookUp(face, thresholds);
        break;
      case .lookDown:
        stepCompleted = _faceProcessor.detectLookDown(face, thresholds);
        break;
      case .smile:
        stepCompleted = _faceProcessor.detectSmile(face, thresholds);
        break;
    }

    if (stepCompleted) {
      debugPrint(
        '✅ Step completed: $step at index ${_coordinator.currentIndex}',
      );
      await _completeStep(step: step);
    }
  }

  Future<void> _completeStep({required LivenessDetectionStep step}) async {
    final int currentIndex = _coordinator.currentIndex;
    debugPrint('🔄 _completeStep called for step $step at index $currentIndex');

    // Prevent double capture for same step
    if (_lastCapturedStepIndex != currentIndex &&
        !_isCapturingStepImage &&
        _latestFrame != null) {
      _isCapturingStepImage = true;
      _lastCapturedStepIndex = currentIndex;

      debugPrint(
        '📸 Capturing image for index $currentIndex, total captured: ${_capturedImages.length}',
      );
      await _captureFromStream(_latestFrame!);
      debugPrint(
        '📸 Captured! Total images: ${_capturedImages.length}/${_shuffledSteps.length}',
      );

      _isCapturingStepImage = false;
    }

    if (mounted) setState(() {});
    debugPrint('➡️ Moving to next step from index $currentIndex');
    _coordinator.nextStep();
    debugPrint('➡️ Now at index ${_coordinator.currentIndex}');
  }

  Future<void> _captureFromStream(CameraImage image) async {
    try {
      if (_capturedImages.length >= _shuffledSteps.length) return;

      final file = await _cameraController.captureFromStream(
        image: image,
        quality: widget.config.imageQuality,
      );

      if (file != null) {
        _capturedImages.add(file);

        widget.config.onEveryImageOnEveryStep?.call(
          List.unmodifiable(_capturedImages),
        );
      }
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  void _takePicture() async {
    try {
      if (_isTakingPicture) return;

      if (mounted) setState(() => _isTakingPicture = true);

      final XFile? finalImage = await _cameraController.takePicture(
        imageQuality: widget.config.imageQuality,
      );

      if (finalImage == null) {
        _startLiveFeed();
        if (mounted) setState(() => _isTakingPicture = false);
        return;
      }

      debugPrint('Final image path: ${finalImage.path}');
      _onDetectionCompleted(imgToReturn: finalImage);
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) setState(() => _isTakingPicture = false);
      _startLiveFeed();
    }
  }

  void _onDetectionCompleted({XFile? imgToReturn}) async {
    final String? imgPath = imgToReturn?.path;

    if (imgPath != null) {
      final File imageFile = File(imgPath);
      final int fileSizeInBytes = await imageFile.length();
      final double sizeInKb = fileSizeInBytes / 1024;
      debugPrint('Image result size : ${sizeInKb.toStringAsFixed(2)} KB');
    }
    if (widget.config.isEnableSnackBar) {
      final snackBar = SnackBar(
        content: Text(
          imgToReturn == null
              ? 'Verification of liveness detection failed, please try again. (Exceeds time limit ${widget.config.durationLivenessVerify ?? 45} second.)'
              : 'Verification of liveness detection success!',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
    if (!mounted) return;
    Navigator.of(context).pop(imgPath);
  }

  void _resetSteps() {
    if (_coordinator.currentIndex != 0) {
      _coordinator.reset();
      _capturedImages.clear();
      _lastCapturedStepIndex = -1;
      _isCapturingStepImage = false;
    }

    if (mounted) setState(() {});
  }

  /// Initialize and shuffle steps fresh each time
  void _initializeShuffledSteps() {
    List<LivenessDetectionStepItem> baseSteps;

    if (widget.config.useCustomizedLabel &&
        widget.config.customizedLabel != null) {
      baseSteps = LivenessSteps.customizedLivenessLabel(
        widget.config.customizedLabel!,
      );
    } else {
      baseSteps = List.from(stepLiveness);
    }

    LivenessSteps.shuffleListLivenessChallenge(
      list: baseSteps,
      isSmileLast: widget.config.useCustomizedLabel
          ? false
          : widget.config.shuffleListWithSmileLast,
    );

    _shuffledSteps = baseSteps;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.config.isDarkMode ? Colors.black : Colors.white,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        _isInfoStepCompleted
            ? _buildDetectionBody()
            : LivenessDetectionTutorialScreen(
                duration: widget.config.durationLivenessVerify ?? 45,
                isDarkMode: widget.config.isDarkMode,
                onStartTap: () {
                  if (mounted) setState(() => _isInfoStepCompleted = true);
                  _startLiveFeed();
                },
              ),
      ],
    );
  }

  Widget _buildDetectionBody() {
    if (!_cameraController.isInitialized) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return LivenessDetectionStepOverlayWidget(
      coordinator: _coordinator,
      cameraController: _cameraController.controller,
      duration: widget.config.durationLivenessVerify,
      showDurationUiText: widget.config.showDurationUiText,
      isDarkMode: widget.config.isDarkMode,
      isFaceDetected: _faceDetectedState,
      camera: CameraPreview(_cameraController.controller!),
      steps: _shuffledSteps,
      showCurrentStep: widget.config.showCurrentStep,
      onCompleted: () => Future.delayed(
        const Duration(milliseconds: 500),
        () => _takePicture(),
      ),
    );
  }
}
