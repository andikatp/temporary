import 'dart:math' as math;

import 'package:flutter/material.dart';

class FaceOverlay extends StatefulWidget {
  const FaceOverlay({
    required this.isWellPositioned,
    super.key,
    this.showProgress = true,
    this.progress = 0,
    this.maxStep = 100,
    this.detectedColor = Colors.green,
    this.undetectedColor = Colors.red,
    this.widthLine = 3,
    this.heightLine = 20,
    this.curve = Curves.easeInOutQuint,
    this.duration = const Duration(milliseconds: 500),
  });

  final bool isWellPositioned;
  final bool showProgress;
  final double progress;
  final double maxStep;
  final Color detectedColor;
  final Color undetectedColor;
  final double widthLine;
  final double heightLine;
  final Curve curve;
  final Duration duration;

  @override
  State<FaceOverlay> createState() => _FaceOverlayState();
}

class _FaceOverlayState extends State<FaceOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _animation;
  double _currentProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation =
        Tween<double>(begin: 0.0, end: widget.progress).animate(
          CurvedAnimation(parent: _animationController!, curve: widget.curve),
        )..addListener(() {
          if (mounted) {
            setState(() => _currentProgress = _animation!.value);
          }
        });

    _animationController!.forward();
  }

  @override
  void didUpdateWidget(FaceOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(begin: _currentProgress, end: widget.progress)
          .animate(
            CurvedAnimation(parent: _animationController!, curve: widget.curve),
          );
      _animationController?.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FaceOverlayPainter(
        isWellPositioned: widget.isWellPositioned,
        showProgress: widget.showProgress,
        progress: _currentProgress,
        maxStep: widget.maxStep,
        detectedColor: widget.detectedColor,
        undetectedColor: widget.undetectedColor,
        widthLine: widget.widthLine,
        heightLine: widget.heightLine,
      ),
    );
  }
}

class FaceOverlayPainter extends CustomPainter {
  FaceOverlayPainter({
    required this.isWellPositioned,
    required this.showProgress,
    required this.progress,
    required this.maxStep,
    required this.detectedColor,
    required this.undetectedColor,
    required this.widthLine,
    required this.heightLine,
  });

  final bool isWellPositioned;
  final bool showProgress;
  final double progress;
  final double maxStep;
  final Color detectedColor;
  final Color undetectedColor;
  final double widthLine;
  final double heightLine;

  @override
  void paint(Canvas canvas, Size size) {
    const double ovalWidth = 240;
    const double ovalHeight = 270;
    final center = Offset(size.width / 2, 240);

    // Draw dark overlay with oval cutout
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = .fill;

    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(
        Rect.fromCenter(center: center, width: ovalWidth, height: ovalHeight),
      )
      ..fillType = .evenOdd;

    canvas.drawPath(overlayPath, overlayPaint);

    // border
    final borderPaint = Paint()
      ..color = isWellPositioned ? detectedColor : undetectedColor
      ..style = .stroke
      ..strokeWidth = 4.0;

    final borderPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, 240),
          width: 240,
          height: 270,
        ),
      );

    canvas.drawPath(borderPath, borderPaint);

    // Draw progress lines around the oval (outside the border)
    if (showProgress) {
      _drawEllipticalProgress(canvas, center, ovalWidth / 2, ovalHeight / 2);
    }
  }

  void _drawEllipticalProgress(
    Canvas canvas,
    Offset center,
    double radiusX,
    double radiusY,
  ) {
    final paint = Paint()
      ..style = .stroke
      ..strokeCap = .round
      ..strokeWidth = widthLine;

    final stepAngle = 2 * math.pi / maxStep;
    final activeSteps = progress.clamp(0, maxStep).floor();

    // Start from top (-π/2) and go clockwise
    const startAngle = -math.pi / 2;

    for (int step = 0; step < maxStep; step++) {
      final angle = startAngle + step * stepAngle;
      final isActive = step < activeSteps;

      // Calculate points on the ellipse (outside the oval border)
      const double gap = 4; // Gap between oval border and progress lines
      final outerRadiusX = radiusX + gap + heightLine;
      final outerRadiusY = radiusY + gap + heightLine;
      final innerRadiusX = radiusX + gap;
      final innerRadiusY = radiusY + gap;

      // For inactive steps, make the outer line shorter
      final effectiveOuterRadiusX = isActive
          ? outerRadiusX
          : outerRadiusX - heightLine / 4;
      final effectiveOuterRadiusY = isActive
          ? outerRadiusY
          : outerRadiusY - heightLine / 4;

      final x1 = center.dx + effectiveOuterRadiusX * math.cos(angle);
      final y1 = center.dy + effectiveOuterRadiusY * math.sin(angle);
      final x2 = center.dx + innerRadiusX * math.cos(angle);
      final y2 = center.dy + innerRadiusY * math.sin(angle);

      if (isWellPositioned) {
        paint.color = isActive ? detectedColor : Colors.grey;
      } else {
        paint.color = undetectedColor;
      }

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) =>
      oldDelegate.isWellPositioned != isWellPositioned ||
      oldDelegate.showProgress != showProgress ||
      oldDelegate.progress != progress ||
      oldDelegate.detectedColor != detectedColor ||
      oldDelegate.undetectedColor != undetectedColor;
}
