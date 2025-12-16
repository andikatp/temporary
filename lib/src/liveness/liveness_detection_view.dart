import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:collection/collection.dart';
import 'package:face_recognition/src/liveness/core/image_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'core/liveness_cooldown_service.dart';
import 'core/machine_learning_kit_helper.dart';
import 'models/liveness_detection_config.dart';
import 'models/liveness_detection_label_model.dart';
import 'models/liveness_detection_step.dart';
import 'models/liveness_detection_step_item.dart';
import 'widgets/liveness_detection_tutorial_screen.dart';
import 'widgets/liveness_step_overlay.dart';

List<LivenessDetectionStepItem> stepLiveness = [
  LivenessDetectionStepItem(
    step: LivenessDetectionStep.blink,
    title: "Blink 2-3 Times",
  ),
  LivenessDetectionStepItem(
    step: LivenessDetectionStep.lookUp,
    title: "Look UP",
  ),
  LivenessDetectionStepItem(
    step: LivenessDetectionStep.lookDown,
    title: "Look DOWN",
  ),
  LivenessDetectionStepItem(
    step: LivenessDetectionStep.lookRight,
    title: "Look RIGHT",
  ),
  LivenessDetectionStepItem(
    step: LivenessDetectionStep.lookLeft,
    title: "Look LEFT",
  ),
  LivenessDetectionStepItem(step: LivenessDetectionStep.smile, title: "Smile"),
];

class LivenessDetectionView extends StatefulWidget {
  final LivenessDetectionConfig config;

  const LivenessDetectionView({super.key, required this.config});

  @override
  State<LivenessDetectionView> createState() => _LivenessDetectionScreenState();
}

class _LivenessDetectionScreenState extends State<LivenessDetectionView> {
  // Camera related variables
  CameraController? _cameraController;
  int _cameraIndex = 0;
  bool _isBusy = false;
  bool _isTakingPicture = false;
  Timer? _timerToDetectFace;
  List<CameraDescription> availableCams = [];

  // Detection state variables
  late bool _isInfoStepCompleted;
  bool _isProcessingStep = false;
  bool _faceDetectedState = false;
  List<LivenessDetectionStepItem> _shuffledSteps = [];

  // Steps related variables
  final GlobalKey<LivenessDetectionStepOverlayWidgetState> _stepsKey =
      GlobalKey<LivenessDetectionStepOverlayWidgetState>();

  Future<void> setApplicationBrightness(double brightness) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(
        brightness,
      );
    } catch (e) {
      debugPrint('Failed to set application brightness');
    }
  }

  Future<void> resetApplicationBrightness() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (e) {
      debugPrint('Failed to reset application brightness');
    }
  }

  static void shuffleListLivenessChallenge({
    required List<LivenessDetectionStepItem> list,
    required bool isSmileLast,
  }) {
    if (isSmileLast) {
      int? smileIndex = list.indexWhere(
        (item) => item.step == LivenessDetectionStep.smile,
      );

      if (smileIndex != -1) {
        LivenessDetectionStepItem smileItem = list.removeAt(smileIndex);
        list.shuffle(Random());
        list.add(smileItem);
      } else {
        list.shuffle(Random());
      }
    } else {
      list.shuffle(Random());
    }
  }

  List<LivenessDetectionStepItem> customizedLivenessLabel(
    LivenessDetectionLabelModel label,
  ) {
    List<LivenessDetectionStepItem> customizedSteps = [];

    if (label.blink != "") {
      customizedSteps.add(
        LivenessDetectionStepItem(
          step: LivenessDetectionStep.blink,
          title: label.blink ?? "Blink 2-3 Times",
        ),
      );
    }
    if (label.lookRight != "") {
      customizedSteps.add(
        LivenessDetectionStepItem(
          step: LivenessDetectionStep.lookRight,
          title: label.lookRight ?? "Look RIGHT",
        ),
      );
    }
    if (label.lookLeft != "") {
      customizedSteps.add(
        LivenessDetectionStepItem(
          step: LivenessDetectionStep.lookLeft,
          title: label.lookLeft ?? "Look LEFT",
        ),
      );
    }
    if (label.lookUp != "") {
      customizedSteps.add(
        LivenessDetectionStepItem(
          step: LivenessDetectionStep.lookUp,
          title: label.lookUp ?? "Look UP",
        ),
      );
      if (label.lookDown != "") {
        customizedSteps.add(
          LivenessDetectionStepItem(
            step: LivenessDetectionStep.lookDown,
            title: label.lookDown ?? "Look DOWN",
          ),
        );
      }
      if (label.smile != "") {
        customizedSteps.add(
          LivenessDetectionStepItem(
            step: LivenessDetectionStep.smile,
            title: label.smile ?? "Smile",
          ),
        );
      }
    }

    return customizedSteps;
  }

  @override
  void initState() {
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
    _timerToDetectFace?.cancel();
    _timerToDetectFace = null;
    _cameraController?.dispose();

    if (widget.config.isEnableMaxBrightness) {
      resetApplicationBrightness();
    }
    super.dispose();
  }

  void _preInitCallBack() {
    _isInfoStepCompleted = !widget.config.startWithInfoScreen;
    _initializeShuffledSteps();
    if (widget.config.isEnableMaxBrightness) {
      setApplicationBrightness(1.0);
    }
  }

  void _postFrameCallBack() async {
    availableCams = await availableCameras();
    if (availableCams.isEmpty) return;

    // Find front camera with 90 deg orientation if possible, else just front
    var frontCam = availableCams.firstWhereOrNull(
      (element) =>
          element.lensDirection == CameraLensDirection.front &&
          element.sensorOrientation == 90,
    );

    frontCam ??= availableCams.firstWhereOrNull(
      (element) => element.lensDirection == CameraLensDirection.front,
    );

    // Fallback to first available if no front cam ??
    frontCam ??= availableCams.first;

    _cameraIndex = availableCams.indexOf(frontCam);

    if (!widget.config.startWithInfoScreen) {
      _startLiveFeed();
    }
  }

  void _startLiveFeed() async {
    if (availableCams.isEmpty) return;
    final camera = availableCams[_cameraIndex];
    _cameraController = CameraController(
      camera,
      widget.config.cameraResolution,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    _cameraController?.initialize().then((_) {
      if (!mounted) return;
      _cameraController?.startImageStream(_processCameraImage);
      setState(() {});
    });
    _startFaceDetectionTimer();
  }

  void _startFaceDetectionTimer() {
    _timerToDetectFace = Timer(
      Duration(seconds: widget.config.durationLivenessVerify ?? 45),
      () => _onDetectionCompleted(imgToReturn: null),
    );
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (availableCams.isEmpty) return;
    final camera = availableCams[_cameraIndex];
    final imageRotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (imageRotation == null) return;

    InputImage? inputImage;

    // Platform agnostic approach to getting InputImage
    // But keeping it simple as per user snippet
    if (Platform.isAndroid) {
      if (cameraImage.format.group == ImageFormatGroup.nv21) {
        inputImage = InputImage.fromBytes(
          bytes: cameraImage.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(
              cameraImage.width.toDouble(),
              cameraImage.height.toDouble(),
            ),
            rotation: imageRotation,
            format: InputImageFormat.nv21,
            bytesPerRow: cameraImage.planes[0].bytesPerRow,
          ),
        );
      }
    } else if (Platform.isIOS) {
      if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        inputImage = InputImage.fromBytes(
          bytes: cameraImage.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(
              cameraImage.width.toDouble(),
              cameraImage.height.toDouble(),
            ),
            rotation: imageRotation,
            format: InputImageFormat.bgra8888,
            bytesPerRow: cameraImage.planes[0].bytesPerRow,
          ),
        );
      }
    }

    if (inputImage != null) {
      _processImage(inputImage, cameraImage, imageRotation.rawValue);
    }
  }

  Future<void> _processImage(
    InputImage inputImage,
    CameraImage cameraImage,
    int rotation,
  ) async {
    if (_isBusy) return;
    _isBusy = true;

    final faces = await MachineLearningKitHelper.instance.processInputImage(
      inputImage,
    );

    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      if (faces.isEmpty) {
        _resetSteps();
        if (mounted) setState(() => _faceDetectedState = false);
      } else {
        if (mounted) setState(() => _faceDetectedState = true);
        final currentIndex = _stepsKey.currentState?.currentIndex ?? 0;
        List<LivenessDetectionStepItem> currentSteps = _getStepsToUse();
        if (currentIndex < currentSteps.length) {
          _detectFace(
            face: faces.first,
            step: currentSteps[currentIndex].step,
            cameraImage: cameraImage,
            rotation: rotation,
          );
        }
      }
    } else {
      _resetSteps();
    }

    _isBusy = false;
    if (mounted) setState(() {});
  }

  void _detectFace({
    required Face face,
    required LivenessDetectionStep step,
    required CameraImage cameraImage,
    required int rotation,
  }) async {
    if (_isProcessingStep) return;

    // debugPrint('Current Step: $step');

    switch (step) {
      case LivenessDetectionStep.blink:
        await _handlingBlinkStep(
          face: face,
          step: step,
          cameraImage: cameraImage,
          rotation: rotation,
        );
        break;

      case LivenessDetectionStep.lookRight:
        await _handlingTurnRight(
          face: face,
          step: step,
          cameraImage: cameraImage,
          rotation: rotation,
        );
        break;

      case LivenessDetectionStep.lookLeft:
        await _handlingTurnLeft(
          face: face,
          step: step,
          cameraImage: cameraImage,
          rotation: rotation,
        );
        break;

      case LivenessDetectionStep.lookUp:
        await _handlingLookUp(
          face: face,
          step: step,
          cameraImage: cameraImage,
          rotation: rotation,
        );
        break;

      case LivenessDetectionStep.lookDown:
        await _handlingLookDown(
          face: face,
          step: step,
          cameraImage: cameraImage,
          rotation: rotation,
        );
        break;

      case LivenessDetectionStep.smile:
        await _handlingSmile(
          face: face,
          step: step,
          cameraImage: cameraImage,
          rotation: rotation,
        );
        break;
    }
  }

  // List to store images captured at each step
  final List<File> _capturedImages = [];

  Future<void> _completeStep({
    required LivenessDetectionStep step,
    required CameraImage cameraImage,
    required int rotation,
  }) async {
    _startProcessing(); // UI Loading

    // Non-blocking capture
    _captureStepImage(cameraImage, rotation);

    if (mounted) setState(() {});
    await _stepsKey.currentState?.nextPage();
    _stopProcessing();
  }

  Future<void> _captureStepImage(CameraImage cameraImage, int rotation) async {
    try {
      // Prepare data for isolate
      final data = CameraImageData(
        planesBytes: cameraImage.planes.map((p) => p.bytes).toList(),
        planesBytesPerRow: cameraImage.planes
            .map((p) => p.bytesPerRow)
            .toList(),
        width: cameraImage.width,
        height: cameraImage.height,
        format: cameraImage.format.group,
        rotation: rotation,
      );

      // Run conversion in background
      compute(convertAndSaveImage, data)
          .then((file) {
            _capturedImages.add(file);
          })
          .catchError((e) {
            debugPrint("Error converting image: $e");
          });
    } catch (e) {
      debugPrint('Error capturing step image: $e');
    }
  }

  // Clean up _takePicture logic that was blocking
  void _takePicture() async {
    // Logic handled via stream now for steps.
    // If we need a final high-res picture, we can keep using old logic or this new logic.
    // For consistency, let's use the stream logic if we have the last frame, but we don't here easily.
    // So we will trigger a final frame logic or just reuse the last captured one?
    // Since user wants "each step", and we just completed the last step, we should have the image from the last step.

    // However, the original flow had a separate "take picture" at the end.
    // We will perform a final capture using the stream if possible, or fallback to blocking capture if really needed.
    // But let's try to just finish since we captured all steps.

    // If we *really* need a final standalone image separate from the steps:
    if (_cameraController == null || _isTakingPicture) return;
    if (mounted) setState(() => _isTakingPicture = true);

    try {
      // Try non-blocking if possible? No, we don't have the frame here.
      // We'll stick to blocking for the FINAL one if strictly required, or just use the last step image.
      // Let's assume the "Success" means we have what we need.
      // We'll just finish.

      File? finalImage;
      if (_capturedImages.isNotEmpty) {
        finalImage = _capturedImages.last;
      }

      _onDetectionCompleted(
        imgToReturn: finalImage != null ? XFile(finalImage.path) : null,
      );
    } catch (e) {
      _onDetectionCompleted(imgToReturn: null);
    }
    if (mounted) setState(() => _isTakingPicture = false);
  }

  void _onDetectionCompleted({XFile? imgToReturn}) async {
    final String? imgPath = imgToReturn?.path;

    if (imgPath != null) {
      final File imageFile = File(imgPath);
      final int fileSizeInBytes = await imageFile.length();
      final double sizeInKb = fileSizeInBytes / 1024;
      debugPrint('Image result size : ${sizeInKb.toStringAsFixed(2)} KB');
    }

    // Call the callback with the list of images
    if (widget.config.onStepImagesCaptured != null) {
      widget.config.onStepImagesCaptured!(_capturedImages);
    }

    if (widget.config.isEnableSnackBar) {
      final snackBar = SnackBar(
        content: Text(
          imgToReturn == null
              ? 'Verification failed. Time limit exceeded or face lost.'
              : 'Verification success!',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }

    if (imgPath == null && widget.config.enableCooldownOnFailure) {
      await LivenessCooldownService.instance.recordFailedAttempt();
    } else if (imgPath != null && widget.config.enableCooldownOnFailure) {
      await LivenessCooldownService.instance.recordSuccessfulAttempt();
    }

    if (!mounted) return;
    Navigator.of(context).pop(imgPath);
  }

  void _resetSteps() {
    // List<LivenessDetectionStepItem> currentSteps = _getStepsToUse();

    if (_stepsKey.currentState != null &&
        _stepsKey.currentState!.currentIndex != 0) {
      _stepsKey.currentState?.reset();
    }

    if (mounted) setState(() {});
  }

  void _startProcessing() {
    if (!mounted) return;
    if (mounted) setState(() => _isProcessingStep = true);
  }

  void _stopProcessing() {
    if (!mounted) return;
    if (mounted) setState(() => _isProcessingStep = false);
  }

  void _initializeShuffledSteps() {
    List<LivenessDetectionStepItem> baseSteps;

    if (widget.config.useCustomizedLabel &&
        widget.config.customizedLabel != null) {
      baseSteps = customizedLivenessLabel(widget.config.customizedLabel!);
    } else {
      baseSteps = List.from(stepLiveness);
    }

    shuffleListLivenessChallenge(
      list: baseSteps,
      isSmileLast: widget.config.useCustomizedLabel
          ? false
          : widget.config.shuffleListWithSmileLast,
    );

    _shuffledSteps = baseSteps;
  }

  List<LivenessDetectionStepItem> _getStepsToUse() {
    return _shuffledSteps;
  }

  // -- Threshold Handlers --
  // Hardcoded thresholds for now as we didn't implement a global config singleton like the plugin

  Future<void> _handlingBlinkStep({
    required Face face,
    required LivenessDetectionStep step,
    required CameraImage cameraImage,
    required int rotation,
  }) async {
    // Thresholds
    const double leftProb = 0.25;
    const double rightProb = 0.25;

    if ((face.leftEyeOpenProbability ?? 1.0) < leftProb &&
        (face.rightEyeOpenProbability ?? 1.0) < rightProb) {
      await _completeStep(
        step: step,
        cameraImage: cameraImage,
        rotation: rotation,
      );
    }
  }

  Future<void> _handlingTurnRight({
    required Face face,
    required LivenessDetectionStep step,
    required CameraImage cameraImage,
    required int rotation,
  }) async {
    const double angle = -30.0; // Android
    const double angleIOS = 30.0; // IOS

    if (Platform.isAndroid) {
      if ((face.headEulerAngleY ?? 0) < angle) {
        await _completeStep(
          step: step,
          cameraImage: cameraImage,
          rotation: rotation,
        );
      }
    } else {
      if ((face.headEulerAngleY ?? 0) > angleIOS) {
        await _completeStep(
          step: step,
          cameraImage: cameraImage,
          rotation: rotation,
        );
      }
    }
  }

  Future<void> _handlingTurnLeft({
    required Face face,
    required LivenessDetectionStep step,
    required CameraImage cameraImage,
    required int rotation,
  }) async {
    const double angle = 30.0;
    const double angleIOS = -30.0;

    if (Platform.isAndroid) {
      if ((face.headEulerAngleY ?? 0) > angle) {
        await _completeStep(
          step: step,
          cameraImage: cameraImage,
          rotation: rotation,
        );
      }
    } else {
      if ((face.headEulerAngleY ?? 0) < angleIOS) {
        await _completeStep(
          step: step,
          cameraImage: cameraImage,
          rotation: rotation,
        );
      }
    }
  }

  Future<void> _handlingLookUp({
    required Face face,
    required LivenessDetectionStep step,
    required CameraImage cameraImage,
    required int rotation,
  }) async {
    const double angle = 20.0;
    if ((face.headEulerAngleX ?? 0) > angle) {
      await _completeStep(
        step: step,
        cameraImage: cameraImage,
        rotation: rotation,
      );
    }
  }

  Future<void> _handlingLookDown({
    required Face face,
    required LivenessDetectionStep step,
    required CameraImage cameraImage,
    required int rotation,
  }) async {
    const double angle = -15.0;
    if ((face.headEulerAngleX ?? 0) < angle) {
      await _completeStep(
        step: step,
        cameraImage: cameraImage,
        rotation: rotation,
      );
    }
  }

  Future<void> _handlingSmile({
    required Face face,
    required LivenessDetectionStep step,
    required CameraImage cameraImage,
    required int rotation,
  }) async {
    const double prob = 0.65;
    if ((face.smilingProbability ?? 0) > prob) {
      await _completeStep(
        step: step,
        cameraImage: cameraImage,
        rotation: rotation,
      );
    }
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
    if (_cameraController == null ||
        _cameraController?.value.isInitialized == false) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          color: widget.config.isDarkMode ? Colors.black : Colors.white,
        ),
        LivenessDetectionStepOverlayWidget(
          cameraController: _cameraController,
          duration: widget.config.durationLivenessVerify,
          showDurationUiText: widget.config.showDurationUiText,
          isDarkMode: widget.config.isDarkMode,
          isFaceDetected: _faceDetectedState,
          camera: CameraPreview(_cameraController!),
          key: _stepsKey,
          steps: _getStepsToUse(),
          showCurrentStep: widget.config.showCurrentStep,
          onCompleted: () => Future.delayed(
            const Duration(milliseconds: 500),
            () => _takePicture(),
          ),
        ),
      ],
    );
  }
}
