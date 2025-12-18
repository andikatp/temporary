import 'dart:io';

import 'package:face_recognition/src/liveness_v3/core/index.dart';
import 'package:face_recognition/widget/home_button.dart';
import 'package:flutter/material.dart';

import '../util/colors.dart';
import 'emotion_detection_page.dart';
import 'face_detection_page.dart';
import 'face_recognition_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<File> imagePaths = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightPinkColor,
      appBar: AppBar(
        title: const Text('AI Playground', style: TextStyle(color: white)),
        centerTitle: true,
        foregroundColor: white,
        backgroundColor: darkPinkColor,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FaceDetectionPage(),
                  ),
                ),
                child: const HomeButton(text: "Face detection - Count people"),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FaceRecognitionPage(),
                  ),
                ),
                child: const HomeButton(text: "Face recognition"),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const EmotionDetectionPage(),
                  ),
                ),
                child: const HomeButton(text: "Emotion detection"),
              ),
              // const SizedBox(height: 10),
              // InkWell(
              //   onTap: () {
              //     Navigator.of(context)
              //         .push(
              //           MaterialPageRoute(
              //             builder: (context) => LivenessDetectionView(
              //               config: LivenessDetectionConfig(
              //                 startWithInfoScreen: true,
              //                 showCurrentStep: true,
              //                 isDarkMode: true,
              //                 onStepImagesCaptured: (images) {
              //                   inspect(images.length);
              //                 },
              //               ),
              //             ),
              //           ),
              //         )
              //         .then((value) {
              //           // Value is the path to the captured image
              //           if (value != null && context.mounted) {
              //             ScaffoldMessenger.of(context).showSnackBar(
              //               const SnackBar(
              //                 content: Text(
              //                   "Liveness Verified! Image captured.",
              //                 ),
              //                 backgroundColor: Colors.green,
              //               ),
              //             );
              //           }
              //         });
              //   },
              //   child: const HomeButton(text: "Liveness Check"),
              // ),
              // const SizedBox(height: 10),
              // InkWell(
              //   onTap: () {
              //     Navigator.of(context).push(
              //       MaterialPageRoute(
              //         builder: (context) => LivenessView(
              //           steps: const [
              //             LivenessStep.blink,
              //             LivenessStep.lookUp,
              //             LivenessStep.lookDown,
              //             LivenessStep.lookLeft,
              //             LivenessStep.lookRight,
              //             LivenessStep.smile,
              //           ],
              //           config: const LivenessConfig(
              //             maxDuration: 45,
              //             showStepProgress: true,
              //             showDurationTimer: true,
              //           ),
              //           onCompleted: (result) {
              //             Navigator.of(context).pop();

              //             if (result.success) {
              //               // Show success with image count
              //               ScaffoldMessenger.of(context).showSnackBar(
              //                 SnackBar(
              //                   content: Text(
              //                     'Liveness V2 Success! ${result.images.length} face images captured',
              //                   ),
              //                   backgroundColor: Colors.green,
              //                   duration: const Duration(seconds: 3),
              //                 ),
              //               );

              //               // Show captured images in a dialog
              //               showDialog(
              //                 context: context,
              //                 builder: (context) => AlertDialog(
              //                   title: Text(
              //                     'Captured ${result.images.length} Face Images',
              //                   ),
              //                   content: SizedBox(
              //                     width: 300,
              //                     height: 400,
              //                     child: ListView.builder(
              //                       itemCount: result.images.length,
              //                       itemBuilder: (context, index) {
              //                         return Padding(
              //                           padding: const EdgeInsets.only(
              //                             bottom: 16,
              //                           ),
              //                           child: Column(
              //                             crossAxisAlignment:
              //                                 CrossAxisAlignment.start,
              //                             children: [
              //                               Text(
              //                                 'Step ${index + 1}',
              //                                 style: const TextStyle(
              //                                   fontWeight: FontWeight.bold,
              //                                 ),
              //                               ),
              //                               const SizedBox(height: 8),
              //                               Image.file(
              //                                 result.images[index],
              //                                 height: 150,
              //                                 width: 150,
              //                                 fit: BoxFit.cover,
              //                               ),
              //                             ],
              //                           ),
              //                         );
              //                       },
              //                     ),
              //                   ),
              //                   actions: [
              //                     TextButton(
              //                       onPressed: () {
              //                         Navigator.pop(context);
              //                         // Clean up temp images after viewing
              //                         cleanupLivenessImages(result.images);
              //                       },
              //                       child: const Text('Close'),
              //                     ),
              //                   ],
              //                 ),
              //               );
              //             } else {
              //               // Show failure
              //               ScaffoldMessenger.of(context).showSnackBar(
              //                 SnackBar(
              //                   content: Text(
              //                     'Liveness V2 Failed! Only ${result.images.length} of 6 steps completed',
              //                   ),
              //                   backgroundColor: Colors.red,
              //                 ),
              //               );
              //             }
              //           },
              //         ),
              //       ),
              //     );
              //   },
              //   child: const HomeButton(text: "Liveness V2 (Face Crop)"),
              // ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => LivenessDetectionView(
                        config: LivenessDetectionConfig(
                          useCustomizedLabel: true,
                          customizedLabel: LivenessDetectionLabelModel(
                            blink: 'blink',
                            lookDown: 'lookDown',
                            lookLeft: 'lookLeft',
                            lookRight: 'lookRight',
                            lookUp: 'lookUp',
                            smile: 'smile',
                          ),
                          onEveryImageOnEveryStep: (images) {
                            setState(() => imagePaths = images);
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: const HomeButton(text: "Liveness V3"),
              ),

              const SizedBox(height: 10),
              if (imagePaths.isNotEmpty)
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    shrinkWrap: true,
                    scrollDirection: .horizontal,
                    itemCount: imagePaths.length,
                    itemBuilder: (context, index) {
                      return Image.file(
                        File(imagePaths[index].path),
                        height: 150,
                        width: 150,
                        fit: .cover,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
