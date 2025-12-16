import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageHelper {
  static Uint8List processCameraImage(Map<String, dynamic> args) {
    final CameraImage image = args['cameraImage'];
    final int quality = args['quality'];

    final int width = image.width;
    final int height = image.height;

    final img.Image imgImage = img.Image(width: width, height: height);

    if (image.planes.length == 1) {
      // 🔥 NV21 packed into single plane
      final Uint8List bytes = image.planes[0].bytes;
      final int rowStride = image.planes[0].bytesPerRow;

      for (int y = 0; y < height; y++) {
        final int uvRow = (y >> 1) * rowStride;
        for (int x = 0; x < width; x++) {
          final int yIndex = y * rowStride + x;
          final int uvIndex = uvRow + (x & ~1);

          final int yVal = bytes[yIndex];
          final int v = bytes[uvIndex + 1];
          final int u = bytes[uvIndex];

          final int r = (yVal + 1.402 * (v - 128)).round();
          final int g = (yVal - 0.344136 * (u - 128) - 0.714136 * (v - 128))
              .round();
          final int b = (yVal + 1.772 * (u - 128)).round();

          imgImage.setPixelRgb(
            x,
            y,
            r.clamp(0, 255),
            g.clamp(0, 255),
            b.clamp(0, 255),
          );
        }
      }
    } else if (image.planes.length >= 2) {
      // ✅ Normal NV21 (Y + VU)
      final yPlane = image.planes[0];
      final uvPlane = image.planes[1];

      for (int y = 0; y < height; y++) {
        final int uvRow = (y >> 1) * uvPlane.bytesPerRow;
        for (int x = 0; x < width; x++) {
          final int yVal = yPlane.bytes[y * yPlane.bytesPerRow + x];

          final int uvIndex = uvRow + (x & ~1);
          final int v = uvPlane.bytes[uvIndex];
          final int u = uvPlane.bytes[uvIndex + 1];

          final int r = (yVal + 1.402 * (v - 128)).round();
          final int g = (yVal - 0.344136 * (u - 128) - 0.714136 * (v - 128))
              .round();
          final int b = (yVal + 1.772 * (u - 128)).round();

          imgImage.setPixelRgb(
            x,
            y,
            r.clamp(0, 255),
            g.clamp(0, 255),
            b.clamp(0, 255),
          );
        }
      }
    } else {
      throw Exception('Unsupported CameraImage format');
    }

    return Uint8List.fromList(img.encodeJpg(imgImage, quality: quality));
  }
}
