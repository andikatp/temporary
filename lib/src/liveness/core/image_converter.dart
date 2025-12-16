import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Data class to pass to isolate
class CameraImageData {
  final List<Uint8List> planesBytes;
  final List<int> planesBytesPerRow;
  final int width;
  final int height;
  final ImageFormatGroup format;
  final int rotation;

  CameraImageData({
    required this.planesBytes,
    required this.planesBytesPerRow,
    required this.width,
    required this.height,
    required this.format,
    required this.rotation,
  });
}

Future<File> convertAndSaveImage(CameraImageData data) async {
  img.Image? image;

  if (data.format == ImageFormatGroup.nv21) {
    // Android YUV420/NV21
    image = _convertYUV420ToImage(data);
  } else if (data.format == ImageFormatGroup.bgra8888) {
    // iOS BGRA8888
    image = _convertBGRA8888ToImage(data);
  }

  if (image == null) {
    throw Exception("Unsupported image format or conversion failed");
  }

  // Rotate if needed
  if (data.rotation != 0) {
    image = img.copyRotate(image, angle: data.rotation);
  }

  // Encode to JPEG
  final jpegBytes = img.encodeJpg(image, quality: 85);

  // Save to file
  final tempDir = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${tempDir.path}/$timestamp.jpg');
  await file.writeAsBytes(jpegBytes);
  return file;
}

img.Image _convertBGRA8888ToImage(CameraImageData data) {
  final width = data.width;
  final height = data.height;
  final bytes = data.planesBytes[0];

  // Create image
  // image package uses format:
  // for version 4.x: img.Image(width: width, height: height, numChannels: 4)
  // Let's assume recent image package.
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bytes.buffer,
    order: img.ChannelOrder.bgra,
  );

  return image;
}

img.Image _convertYUV420ToImage(CameraImageData data) {
  // NV21 format: Y plane, then UV plane (interleaved)
  // Android CameraImage usually gives 3 planes: Y, U, V with strides.
  // But ImageFormatGroup.nv21 implies ... wait.
  // The camera package on Android with 'nv21' output:
  // planes[0] is Y.
  // planes[1] is U.
  // planes[2] is V.
  // Pixel stride and row stride matter.

  final width = data.width;
  final height = data.height;
  final uvRowStride = data.planesBytesPerRow[1];
  final uvPixelStride = 2; // Usually 2 for NV21/420-888

  final image = img.Image(width: width, height: height);

  var yPlane = data.planesBytes[0];
  var uPlane = data.planesBytes[1];
  var vPlane = data.planesBytes[2];

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int uvIndex =
          (uvPixelStride * (x / 2).floor()) + (uvRowStride * (y / 2).floor());
      final int index = y * width + x;

      // Safety check
      if (index >= yPlane.length ||
          uvIndex >= uPlane.length ||
          uvIndex >= vPlane.length)
        continue;

      final yp = yPlane[index];
      final up = uPlane[uvIndex];
      final vp = vPlane[uvIndex];

      // Convert YUV to RGB
      int r = (yp + (1.370705 * (vp - 128))).round().clamp(0, 255);
      int g = (yp - (0.337633 * (up - 128)) - (0.698001 * (vp - 128)))
          .round()
          .clamp(0, 255);
      int b = (yp + (1.732446 * (up - 128))).round().clamp(0, 255);

      image.setPixelRgb(x, y, r, g, b);
    }
  }
  return image;
}
