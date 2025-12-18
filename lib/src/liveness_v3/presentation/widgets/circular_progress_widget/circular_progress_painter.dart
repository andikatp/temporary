import 'dart:math' as math;

import 'package:flutter/material.dart';

class CircularProgressPainter extends CustomPainter {
  final double currentStep;
  final double maxStep;
  final double widthLine;
  final double heightLine;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Gradient? gradientColor;

  CircularProgressPainter({
    required this.maxStep,
    required this.widthLine,
    required this.heightLine,
    required this.currentStep,
    required this.selectedColor,
    required this.unselectedColor,
    required this.gradientColor,
  });
  double get maxDefinedSize {
    return math.max(1, math.max(0, 0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Paint paint = Paint()..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      height: h - maxDefinedSize,
      width: w - maxDefinedSize,
    );

    if (gradientColor != null) {
      paint.shader = gradientColor!.createShader(rect);
    }
    _drawStepArc(canvas, paint, rect, size);
  }

  /// Draw a series of arcs, each composing the full steps of the indicator
  void _drawStepArc(Canvas canvas, Paint paint, Rect rect, Size size) {
    final centerX = rect.center.dx;
    final centerY = rect.center.dy;
    final radius = math.min(centerX, centerY);

    final stepAngle = 2 * math.pi / maxStep;
    final activeSteps = currentStep.clamp(0, maxStep).floor();

    for (int step = 0; step < maxStep; step++) {
      final angle = step * stepAngle;

      final isActive = step < activeSteps;

      final outerRadius = radius - (isActive ? 0 : heightLine / 2);
      final innerRadius = radius - heightLine;

      final x1 = centerX + outerRadius * math.cos(angle);
      final y1 = centerY + outerRadius * math.sin(angle);

      final x2 = centerX + innerRadius * math.cos(angle);
      final y2 = centerY + innerRadius * math.sin(angle);

      paint
        ..color = isActive
            ? selectedColor ?? Colors.red
            : unselectedColor ?? Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = widthLine;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
