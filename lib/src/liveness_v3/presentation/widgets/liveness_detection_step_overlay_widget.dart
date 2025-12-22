import 'dart:async';

import 'package:camera/camera.dart';
import 'package:face_recognition/src/liveness_v3/core/index.dart';
import 'package:face_recognition/src/liveness_v3/presentation/liveness_detection_coordinator.dart';
import 'package:face_recognition/src/liveness_v3/presentation/widgets/circular_progress_widget/circular_progress_widget.dart';
import 'package:face_recognition/src/liveness_v3/presentation/widgets/custom_back_button.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LivenessDetectionStepOverlayWidget extends StatefulWidget {
  final LivenessDetectionCoordinator coordinator;
  final List<LivenessDetectionStepItem> steps;
  final VoidCallback onCompleted;
  final Widget camera;
  final CameraController? cameraController;
  final bool isFaceDetected;
  final bool showCurrentStep;
  final bool isDarkMode;
  final bool showDurationUiText;
  final int? duration;

  const LivenessDetectionStepOverlayWidget({
    super.key,
    required this.coordinator,
    required this.steps,
    required this.onCompleted,
    required this.camera,
    required this.cameraController,
    required this.isFaceDetected,
    this.showCurrentStep = false,
    this.isDarkMode = true,
    this.showDurationUiText = false,
    this.duration,
  });

  @override
  State<LivenessDetectionStepOverlayWidget> createState() =>
      LivenessDetectionStepOverlayWidgetState();
}

class LivenessDetectionStepOverlayWidgetState
    extends State<LivenessDetectionStepOverlayWidget> {
  bool _isLoading = false;
  double _currentStepIndicator = 0;
  late final PageController _pageController;
  late CircularProgressWidget _circularProgressWidget;

  bool _pageViewVisible = false;
  Timer? _countdownTimer;
  int _remainingDuration = 0;

  static const double _indicatorMaxStep = 100;
  static const double _heightLine = 25;

  double _getStepIncrement(int stepLength) {
    return 100 / stepLength;
  }

  String get stepCounter =>
      "${widget.coordinator.currentIndex}/${widget.steps.length}";

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeTimer();
    widget.coordinator.addListener(_onCoordinatorChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => setState(() => _pageViewVisible = true),
    );
    debugPrint('showCurrentStep ${widget.showCurrentStep}');
  }

  void _onCoordinatorChanged() {
    final currentIndex = widget.coordinator.currentIndex;
    final isProcessing = widget.coordinator.isProcessing;

    // Update loading state
    if (_isLoading != isProcessing) {
      if (mounted) setState(() => _isLoading = isProcessing);
    }

    // Update page view and progress
    if (_pageController.hasClients) {
      _pageController.jumpToPage(currentIndex);
    }

    final newProgress = currentIndex * _getStepIncrement(widget.steps.length);
    if (_currentStepIndicator != newProgress) {
      if (mounted) {
        setState(() {
          _currentStepIndicator = newProgress;
          _circularProgressWidget = _buildCircularIndicator();
        });
      }
    }

    // Check for completion
    if (widget.coordinator.isCompleted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) widget.onCompleted();
      });
    }
  }

  void _initializeControllers() {
    _pageController = PageController(initialPage: 0);
    _circularProgressWidget = _buildCircularIndicator();
  }

  void _initializeTimer() {
    if (widget.duration != null && widget.showDurationUiText) {
      _remainingDuration = widget.duration!;
      _startCountdownTimer();
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingDuration > 0) {
        setState(() => _remainingDuration--);
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  CircularProgressWidget _buildCircularIndicator() {
    double scale = 1.0;
    if (widget.cameraController != null &&
        widget.cameraController!.value.isInitialized) {
      final cameraAspectRatio = widget.cameraController!.value.aspectRatio;
      const containerAspectRatio = 1.0;
      scale = cameraAspectRatio / containerAspectRatio;
      if (scale < 1.0) {
        scale = 1.0 / scale;
      }
    }

    return CircularProgressWidget(
      unselectedColor: Colors.grey,
      selectedColor: Colors.green,
      heightLine: _heightLine,
      current: _currentStepIndicator,
      maxStep: _indicatorMaxStep,
      child: Transform.scale(
        scale: scale,
        child: Center(child: widget.camera),
      ),
    );
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_onCoordinatorChanged);
    _pageController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const .all(16),
      child: Container(
        margin: const .all(12),
        height: double.infinity,
        width: double.infinity,
        color: Colors.transparent,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: widget.showCurrentStep
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CustomBackButton(onTap: () => Navigator.pop(context)),
                        Visibility(
                          replacement: const SizedBox.shrink(),
                          visible: widget.showDurationUiText,
                          child: Text(
                            _getRemainingTimeText(_remainingDuration),
                            style: TextStyle(
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          stepCounter,
                          style: TextStyle(
                            color: widget.isDarkMode
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ],
                    )
                  : CustomBackButton(onTap: () => Navigator.pop(context)),
            ),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      mainAxisAlignment: .center,
      crossAxisAlignment: .center,
      mainAxisSize: .max,
      spacing: 16,
      children: [
        _buildCircularCamera(),
        _buildFaceDetectionStatus(),
        Visibility(
          visible: _pageViewVisible,
          replacement: const CircularProgressIndicator.adaptive(),
          child: _buildStepPageView(),
        ),
      ],
    );
  }

  Widget _buildCircularCamera() {
    return SizedBox(height: 300, width: 300, child: _circularProgressWidget);
  }

  String _getRemainingTimeText(int duration) {
    int minutes = duration ~/ 60;
    int seconds = duration % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  Widget _buildFaceDetectionStatus() {
    return Row(
      mainAxisAlignment: .center,
      spacing: 16,
      children: [
        SizedBox(
          child: widget.isDarkMode
              ? LottieBuilder.asset(
                  widget.isFaceDetected
                      ? 'assets/animations/face_detected.json'
                      : 'assets/animations/face_id_anim.json',
                  height: widget.isFaceDetected ? 32 : 22,
                  width: widget.isFaceDetected ? 32 : 22,
                )
              : ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    widget.isFaceDetected ? Colors.green : Colors.black,
                    BlendMode.modulate,
                  ),
                  child: LottieBuilder.asset(
                    widget.isFaceDetected
                        ? 'assets/animations/face_detected.json'
                        : 'assets/animations/face_id_anim.json',
                    height: widget.isFaceDetected ? 32 : 22,
                    width: widget.isFaceDetected ? 32 : 22,
                  ),
                ),
        ),
        Text(
          widget.isFaceDetected
              ? 'Wajah ditemukan'
              : 'Pastikan wajah anda di dalam oval',
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildStepPageView() {
    return SizedBox(
      height: MediaQuery.of(context).size.height / 10,
      width: MediaQuery.of(context).size.width,
      child: AbsorbPointer(
        absorbing: true,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.steps.length,
          itemBuilder: _buildStepItem,
        ),
      ),
    );
  }

  Widget _buildStepItem(BuildContext context, int index) {
    return Padding(
      padding: const .all(10),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDarkMode ? Colors.black : Colors.white,
          borderRadius: .circular(20),
        ),
        alignment: .center,
        margin: const .symmetric(horizontal: 30),
        padding: const .all(10),
        child: Text(
          widget.steps[index].title,
          textAlign: .center,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black,
            fontSize: 24,
            fontWeight: .bold,
          ),
        ),
      ),
    );
  }
}
