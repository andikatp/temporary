import 'package:face_recognition/pages/home_page.dart';
import 'package:face_recognition/util/colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'view_model/emotion_detection_model.dart';
import 'view_model/face_detection_viewmodel.dart';
import 'view_model/face_recognition_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FaceDetectionModel()),
        ChangeNotifierProvider(create: (_) => FaceRecognitionModel()),
        ChangeNotifierProvider(create: (_) => EmotionDetectionModel()),
      ],
      child: MaterialApp(
        title: 'AI Playground',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: darkPinkColor),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
