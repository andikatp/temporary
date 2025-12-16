// import 'package:face_auth_engine/face_auth_engine.dart';
// import 'package:face_recognition/util/face_firestore_repo.dart';
// import 'package:flutter_liveness_detection_randomized_plugin/index.dart';

// class FaceEnrollPage extends StatefulWidget {
//   const FaceEnrollPage({super.key});

//   @override
//   State<FaceEnrollPage> createState() => _FaceEnrollPageState();
// }

// class _FaceEnrollPageState extends State<FaceEnrollPage> {
//   final engine = FaceAuthEngine(
//     config: FaceConfig(recognitionThreshold: 1.0, requiredEnrollmentSamples: 5),
//   );

//   final repo = FaceFirestoreRepo();
//   String status = 'Idle';

//   @override
//   void dispose() {
//     engine.dispose();
//     super.dispose();
//   }

//   Future<File?> _runLiveness() async {
//     final path = await FlutterLivenessDetectionRandomizedPlugin.instance
//         .livenessDetection(
//           context: context,
//           config: LivenessDetectionConfig(
//             cameraResolution: ResolutionPreset.medium,
//             imageQuality: 90,
//             shuffleListWithSmileLast: true,
//           ),
//         );

//     return path != null ? File(path) : null;
//   }

//   Future<String?> _promptName() {
//     String name = '';
//     return showDialog<String>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Enter Name'),
//         content: TextField(
//           autofocus: true,
//           onChanged: (value) => name = value,
//           decoration: const InputDecoration(hintText: 'John Doe'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, name),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   /// ENROLL
//   Future<void> enroll(String userId) async {
//     // 1. Check if already complete (unlikely for new enrollment, but good practice)
//     if (engine.isEnrollmentComplete(userId)) {
//       await _saveEnrollment(userId);
//       return;
//     }

//     // 2. Loop until complete
//     while (!engine.isEnrollmentComplete(userId)) {
//       final currentCount = engine.getEnrollmentSampleCount(userId) + 1;
//       print("Current count: ${currentCount.toString()}");
//       final totalNeeded = engine.config.requiredEnrollmentSamples;

//       setState(
//         () => status = 'Capturing sample $currentCount of $totalNeeded...',
//       );

//       // Run liveness
//       final file = await _runLiveness();

//       // If user cancelled liveness, stop the process
//       if (file == null) {
//         setState(() => status = 'Enrollment cancelled');
//         return;
//       }

//       setState(() => status = 'Processing sample $currentCount...');
//       final embedding = await engine.extractEmbedding(file);
//       engine.enrollSample(userId, embedding);
//     }

//     // 3. Save to Firestore
//     await _saveEnrollment(userId);
//   }

//   Future<void> _saveEnrollment(String userId) async {
//     setState(() => status = 'Finalizing enrollment...');
//     final embeddingData = engine.buildFinalEmbedding(userId);
//     if (embeddingData == null) {
//       setState(() => status = 'Enrollment failed: No embedding data');
//       return;
//     }

//     final finalEmbedding = FaceEmbedding(
//       personId: userId,
//       embedding: embeddingData,
//       version: '1.0',
//     );

//     await repo.saveEmbedding(userId: userId, embedding: finalEmbedding);
//     setState(() => status = 'Enrollment completed for $userId');
//   }

//   /// RECOGNIZE
//   Future<void> recognize() async {
//     setState(() => status = 'Loading known faces...');
//     final embeddings = await repo.loadAllEmbeddings();

//     engine.clear();
//     engine.importEmbeddings(embeddings);

//     final file = await _runLiveness();
//     if (file == null) return;

//     setState(() => status = 'Recognizing...');
//     final embedding = await engine.extractEmbedding(file);
//     final personId = engine.recognize(embedding);

//     setState(() {
//       status = personId != null ? 'Recognized: $personId' : 'Unknown face';
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Face Auth')),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Text(status),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () async {
//                 final name = await _promptName();
//                 if (name != null && name.trim().isNotEmpty) {
//                   enroll(name.trim());
//                 }
//               },
//               child: const Text('Enroll Face'),
//             ),
//             ElevatedButton(
//               onPressed: recognize,
//               child: const Text('Recognize Face'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
