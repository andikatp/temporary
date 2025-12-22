import 'dart:math';

import 'package:face_recognition/src/liveness_v3/core/index.dart';

class LivenessSteps {
  static void shuffleListLivenessChallenge({
    required List<LivenessDetectionStepItem> list,
    required bool isSmileLast,
  }) {
    if (isSmileLast) {
      int? smileIndex = list.indexWhere(
        (item) => item.step == LivenessDetectionStep.smile,
      );

      if (smileIndex != -1) {
        LivenessDetectionStepItem smileItem = list.removeAt(smileIndex);
        list.shuffle(Random());
        list.add(smileItem);
      } else {
        list.shuffle(Random());
      }
    } else {
      list.shuffle(Random());
    }
  }

  static List<T> manualRandomItemLiveness<T>(List<T> list) {
    final random = Random();
    List<T> shuffledList = List.from(list);
    for (int i = shuffledList.length - 1; i > 0; i--) {
      int j = random.nextInt(i + 1);

      T temp = shuffledList[i];
      shuffledList[i] = shuffledList[j];
      shuffledList[j] = temp;
    }
    return shuffledList;
  }

  static List<LivenessDetectionStepItem> customizedLivenessLabel(
    LivenessDetectionLabelModel label,
  ) {
    List<LivenessDetectionStepItem> customizedSteps = [];

    // Add blink step if not explicitly skipped (empty string skips)
    if (label.blink != "") {
      customizedSteps.add(
        LivenessDetectionStepItem(
          step: LivenessDetectionStep.blink,
          title: label.blink ?? "Blink 2-3 Times",
        ),
      );
    }

    // Add lookRight step if not explicitly skipped
    if (label.lookRight != "") {
      customizedSteps.add(
        LivenessDetectionStepItem(
          step: LivenessDetectionStep.lookRight,
          title: label.lookRight ?? "Look RIGHT",
        ),
      );
    }

    // Add lookLeft step if not explicitly skipped
    if (label.lookLeft != "") {
      customizedSteps.add(
        LivenessDetectionStepItem(
          step: LivenessDetectionStep.lookLeft,
          title: label.lookLeft ?? "Look LEFT",
        ),
      );
    }

    // Add lookUp step if not explicitly skipped
    if (label.lookUp != "") {
      customizedSteps.add(
        LivenessDetectionStepItem(
          step: LivenessDetectionStep.lookUp,
          title: label.lookUp ?? "Look UP",
        ),
      );
    }

    // Add lookDown step if not explicitly skipped
    if (label.lookDown != "") {
      customizedSteps.add(
        LivenessDetectionStepItem(
          step: LivenessDetectionStep.lookDown,
          title: label.lookDown ?? "Look DOWN",
        ),
      );
    }

    // Add smile step if not explicitly skipped
    if (label.smile != "") {
      customizedSteps.add(
        LivenessDetectionStepItem(
          step: LivenessDetectionStep.smile,
          title: label.smile ?? "Smile",
        ),
      );
    }

    return customizedSteps;
  }
}
