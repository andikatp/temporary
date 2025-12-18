import 'package:face_recognition/src/liveness_v3/core/index.dart';

List<LivenessDetectionStepItem> stepLiveness = [
  LivenessDetectionStepItem(step: .blink, title: "Berkedip 2-3 kali"),
  LivenessDetectionStepItem(step: .lookUp, title: "Lihat Atas"),
  LivenessDetectionStepItem(step: .lookDown, title: "Lihat Bawah"),
  LivenessDetectionStepItem(step: .lookRight, title: "Lihat Kanan"),
  LivenessDetectionStepItem(step: .lookLeft, title: "Lihat Kiri"),
  LivenessDetectionStepItem(step: .smile, title: "Senyum"),
];
