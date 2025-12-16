import 'dart:math' as math;

import 'package:face_recognition/util/face_config.dart';

class FaceRecognizer {
  double distance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return math.sqrt(sum);
  }

  List<double> averageEmbeddings(List<List<double>> vectors) {
    final len = vectors.first.length;
    final avg = List.filled(len, 0.0);

    for (final v in vectors) {
      for (int i = 0; i < len; i++) {
        avg[i] += v[i];
      }
    }

    for (int i = 0; i < len; i++) {
      avg[i] /= vectors.length;
    }

    final norm = math.sqrt(avg.fold(0, (s, v) => s + v * v));
    return avg.map((v) => v / norm).toList();
  }

  String recognize(
    List<double> probe,
    Map<String, List<List<double>>> enrolled,
  ) {
    String best = 'Unknown';
    double minDist = double.infinity;

    for (final entry in enrolled.entries) {
      final avg = averageEmbeddings(entry.value);
      final d = distance(probe, avg);

      if (d < minDist && d < FaceConfig.recognitionThreshold) {
        minDist = d;
        best = entry.key;
      }
    }

    return best;
  }
}
