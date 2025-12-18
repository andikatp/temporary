import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageHelper {
  static Uint8List processCameraImage(Map<String, dynamic> args) {
    final CameraImage image = args['cameraImage'];
    final int quality = args['quality'];
    final int rotation = args['rotation'];
    final bool isFrontCamera = args['isFrontCamera'];

    img.Image converted;

    switch (image.format.group) {
      case .bgra8888:
        converted = _fromBGRA8888(image);
        break;

      case .yuv420:
        converted = _fromYUV420(image);
        break;

      case .nv21:
        converted = _fromNV21(image);
        break;

      default:
        throw UnsupportedError(
          'Unsupported image format: ${image.format.group}',
        );
    }

    // 🔴 ROTATION FIX
    converted = _applyRotation(
      converted,
      rotation: rotation,
      isFrontCamera: isFrontCamera,
    );

    return Uint8List.fromList(img.encodeJpg(converted, quality: quality));
  }

  static img.Image _applyRotation(
    img.Image image, {
    required int rotation,
    required bool isFrontCamera,
  }) {
    img.Image rotated;

    switch (rotation) {
      case 90:
        rotated = img.copyRotate(image, angle: 90);
        break;
      case 180:
        rotated = img.copyRotate(image, angle: 180);
        break;
      case 270:
        rotated = img.copyRotate(image, angle: -90);
        break;
      default:
        rotated = image;
    }

    // Front camera mirror correction
    if (isFrontCamera) {
      rotated = img.flipHorizontal(rotated);
    }

    return rotated;
  }

  // ================= iOS =================
  static img.Image _fromBGRA8888(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  // ================= Android (YUV420_888) =================
  static img.Image _fromYUV420(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final img.Image imgImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x * yPixelStride;
        final int uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;

        final int yp = yPlane.bytes[yIndex];
        final int up = uPlane.bytes[uvIndex];
        final int vp = vPlane.bytes[uvIndex];

        _setPixel(imgImage, x, y, yp, up, vp);
      }
    }

    return imgImage;
  }

  // ================= Android (NV21 – Samsung A03) =================
  static img.Image _fromNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Uint8List bytes = image.planes[0].bytes;
    final int frameSize = width * height;

    final img.Image imgImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int uvIndex = frameSize + (y >> 1) * width + (x & ~1);

        final int yp = bytes[yIndex];
        final int v = bytes[uvIndex];
        final int u = bytes[uvIndex + 1];

        _setPixel(imgImage, x, y, yp, u, v);
      }
    }

    return imgImage;
  }

  static void _setPixel(
    img.Image image,
    int x,
    int y,
    int yVal,
    int uVal,
    int vVal,
  ) {
    final int r = (yVal + 1.402 * (vVal - 128)).round();
    final int g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128))
        .round();
    final int b = (yVal + 1.772 * (uVal - 128)).round();

    image.setPixelRgb(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
  }
}
