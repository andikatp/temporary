import 'dart:developer';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceAlignmentHelper {
  // Canonical 5-point landmark positions for MobileFaceNet (112x112 image)
  // These are the expected positions after alignment
  static const List<List<double>> canonicalLandmarks = [
    [38.2946, 51.6963], // Left eye
    [73.5318, 51.5014], // Right eye
    [56.0252, 71.7366], // Nose
    [41.5493, 92.3655], // Left mouth
    [70.7299, 92.2041], // Right mouth
  ];

  /// Aligns a face image using similarity transform based on detected landmarks
  /// Returns a 112x112 aligned face image ready for MobileFaceNet
  static img.Image alignFace(
    img.Image originalImage,
    List<FaceLandmark> detectedLandmarks,
  ) {
    // Extract detected landmark positions
    final List<List<double>> sourceLandmarks = extractOrderedLandmarks(
      detectedLandmarks,
    );

    log('Source landmarks: $sourceLandmarks');
    log('Canonical landmarks: $canonicalLandmarks');

    // Compute similarity transform matrix
    final transform = _computeSimilarityTransform(
      sourceLandmarks,
      canonicalLandmarks,
    );

    log('Transform matrix: $transform');

    // Apply transformation to create aligned face
    final alignedImage = _applyTransform(originalImage, transform, 112, 112);

    return alignedImage;
  }

  /// Computes similarity transform (scale, rotation, translation) from source to destination points
  /// Uses least squares method to find optimal transformation
  static List<double> _computeSimilarityTransform(
    List<List<double>> src,
    List<List<double>> dst,
  ) {
    // We need to solve for [a, b, tx, ty] where:
    // x' = a*x - b*y + tx
    // y' = b*x + a*y + ty
    // This preserves angles and scales uniformly (similarity transform)

    int numPoints = src.length;
    double sumX = 0, sumY = 0, sumU = 0, sumV = 0;
    double sumXX = 0, sumYY = 0, sumXU = 0, sumYU = 0, sumXV = 0, sumYV = 0;

    for (int i = 0; i < numPoints; i++) {
      double x = src[i][0];
      double y = src[i][1];
      double u = dst[i][0];
      double v = dst[i][1];

      sumX += x;
      sumY += y;
      sumU += u;
      sumV += v;
      sumXX += x * x;
      sumYY += y * y;
      sumXU += x * u;
      sumYU += y * u;
      sumXV += x * v;
      sumYV += y * v;
    }

    double n = numPoints.toDouble();
    double d = n * (sumXX + sumYY) - sumX * sumX - sumY * sumY;

    if (d.abs() < 1e-10) {
      throw Exception('Cannot compute similarity transform: singular matrix');
    }

    double a = (n * (sumXU + sumYV) - sumX * sumU - sumY * sumV) / d;
    double b = (n * (sumXV - sumYU) - sumX * sumV + sumY * sumU) / d;
    double tx = (sumU - a * sumX + b * sumY) / n;
    double ty = (sumV - b * sumX - a * sumY) / n;

    return [a, b, tx, ty];
  }

  /// Applies similarity transform to image and returns aligned face
  static img.Image _applyTransform(
    img.Image src,
    List<double> transform,
    int width,
    int height,
  ) {
    double a = transform[0];
    double b = transform[1];
    double tx = transform[2];
    double ty = transform[3];

    // Create output image
    final aligned = img.Image(width: width, height: height);

    // Compute inverse transform to map from destination to source
    double det = a * a + b * b;
    if (det.abs() < 1e-10) {
      throw Exception('Cannot invert transform: determinant too small');
    }

    double aInv = a / det;
    double bInv = -b / det;
    double txInv = -(a * tx + b * ty) / det;
    double tyInv = (b * tx - a * ty) / det;

    // For each pixel in the aligned image, find corresponding pixel in source
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Apply inverse transform
        double srcX = aInv * x - bInv * y + txInv;
        double srcY = bInv * x + aInv * y + tyInv;

        // Bilinear interpolation
        if (srcX >= 0 &&
            srcX < src.width - 1 &&
            srcY >= 0 &&
            srcY < src.height - 1) {
          int x0 = srcX.floor();
          int y0 = srcY.floor();
          int x1 = x0 + 1;
          int y1 = y0 + 1;

          double dx = srcX - x0;
          double dy = srcY - y0;

          img.Pixel p00 = src.getPixel(x0, y0);
          img.Pixel p10 = src.getPixel(x1, y0);
          img.Pixel p01 = src.getPixel(x0, y1);
          img.Pixel p11 = src.getPixel(x1, y1);

          int r = _interpolate(
            p00.r.toInt(),
            p10.r.toInt(),
            p01.r.toInt(),
            p11.r.toInt(),
            dx,
            dy,
          );
          int g = _interpolate(
            p00.g.toInt(),
            p10.g.toInt(),
            p01.g.toInt(),
            p11.g.toInt(),
            dx,
            dy,
          );
          int blue = _interpolate(
            p00.b.toInt(),
            p10.b.toInt(),
            p01.b.toInt(),
            p11.b.toInt(),
            dx,
            dy,
          );

          aligned.setPixelRgb(x, y, r, g, blue);
        } else {
          // Out of bounds - set to black
          aligned.setPixelRgb(x, y, 0, 0, 0);
        }
      }
    }

    return aligned;
  }

  /// Bilinear interpolation helper
  static int _interpolate(
    int v00,
    int v10,
    int v01,
    int v11,
    double dx,
    double dy,
  ) {
    double v0 = v00 * (1 - dx) + v10 * dx;
    double v1 = v01 * (1 - dx) + v11 * dx;
    double v = v0 * (1 - dy) + v1 * dy;
    return v.round().clamp(0, 255);
  }

  static List<List<double>> extractOrderedLandmarks(
    List<FaceLandmark> landmarks,
  ) {
    final map = <FaceLandmarkType, FaceLandmark>{
      for (final l in landmarks) l.type: l,
    };

    final required = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
    ];

    for (final type in required) {
      if (!map.containsKey(type)) {
        throw Exception('Missing required landmark: $type');
      }
    }

    return [
      map[FaceLandmarkType.leftEye]!,
      map[FaceLandmarkType.rightEye]!,
      map[FaceLandmarkType.noseBase]!,
      map[FaceLandmarkType.leftMouth]!,
      map[FaceLandmarkType.rightMouth]!,
    ].map((l) => [l.position.x.toDouble(), l.position.y.toDouble()]).toList();
  }
}
