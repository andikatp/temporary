import 'dart:math' as math;

import 'package:face_recognition/util/face_config.dart';

class EnrollmentManager {
  final Map<String, List<List<double>>> _data = {};

  void enroll(String name, List<double> embedding) {
    _data.putIfAbsent(name, () => []);

    // First sample always allowed
    if (_data[name]!.isNotEmpty) {
      final last = _data[name]!.last;
      final dist = _distance(last, embedding);

      if (dist > 0.9) {
        throw Exception('Face pose too different. Try again.');
      }
    }

    _data[name]!.add(embedding);

    if (_data[name]!.length > FaceConfig.minEnrollmentSamples) {
      _data[name]!.removeAt(0); // sliding window
    }
  }

  bool isEnrollmentComplete(String name) =>
      _data[name]?.length == FaceConfig.minEnrollmentSamples;

  double _distance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return math.sqrt(sum);
  }
}
