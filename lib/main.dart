
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:eyesgym/views/landing_page.dart';


// Main function to get available cameras and run the app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Get list of available cameras
  final cameras = await availableCameras();
  
  // Get the front camera (for eye tracking)
  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );
  
  runApp(MyApp(camera: frontCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  
  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eye Health Camera',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: LandingPage(camera: camera),
    );
  }
}

