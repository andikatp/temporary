import 'dart:typed_data';

import 'package:camera/camera.dart';

extension Nv21Converter on CameraImage {
  Uint8List getNv21Uint8List() {
    final width = this.width;
    final height = this.height;
    final uvRowStride = planes[1].bytesPerRow;
    final uvPixelStride = planes[1].bytesPerPixel!;

    final nv21 = Uint8List(width * height * 3 ~/ 2);

    // Copy Y channel
    var yIndex = 0;
    for (var y = 0; y < height; y++) {
      final yRowIndex = y * planes[0].bytesPerRow;
      for (var x = 0; x < width; x++) {
        nv21[yIndex++] = planes[0].bytes[yRowIndex + x];
      }
    }

    // Copy VU channels
    var uvIndex = width * height;
    for (var y = 0; y < height ~/ 2; y++) {
      final uvRowIndex = y * uvRowStride;
      for (var x = 0; x < width ~/ 2; x++) {
        final uvOffset = uvRowIndex + x * uvPixelStride;
        nv21[uvIndex++] = planes[2].bytes[uvOffset]; // V channel
        nv21[uvIndex++] = planes[1].bytes[uvOffset]; // U channel
      }
    }

    return nv21;
  }
}
