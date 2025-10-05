import 'package:eyesgym/models/eye_state.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionState {
  final List<Face> faces;
  final bool hasFaceDetected;
  final EyeState? eyeState;
  final double fps;
  final int frameCount;

  FaceDetectionState({
    this.faces = const [],
    this.fps = 0.0,
    this.frameCount = 0,
  })  : hasFaceDetected = faces.isNotEmpty,
        eyeState = faces.isNotEmpty && 
                   faces.first.leftEyeOpenProbability != null && 
                   faces.first.rightEyeOpenProbability != null
            ? EyeState(
                leftEyeOpenProbability: faces.first.leftEyeOpenProbability!,
                rightEyeOpenProbability: faces.first.rightEyeOpenProbability!,
              )
            : null;


  FaceDetectionState copyWith({
      List<Face>? faces,
      double? fps,
      int? frameCount,
    }) {
      return FaceDetectionState(
        faces: faces ?? this.faces,
        fps: fps ?? this.fps,
        frameCount: frameCount ?? this.frameCount,
      );
    }

}

class CarState {
  final double xPosition; // -1.0 to 1.0 (left to right)
  final double speed; // 0.0 to 100.0
  final double distance; // Total distance traveled
  final int score;
  
  const CarState({
    this.xPosition = 0.0,
    this.speed = 0.0,
    this.distance = 0.0,
    this.score = 0,
  });
  
  CarState copyWith({
    double? xPosition,
    double? speed,
    double? distance,
    int? score,
  }) {
    return CarState(
      xPosition: xPosition ?? this.xPosition,
      speed: speed ?? this.speed,
      distance: distance ?? this.distance,
      score: score ?? this.score,
    );
  }
}

class Obstacle {
  double yPosition; // 0.0 to 1.0 (top to bottom)
  final double xPosition; // -1.0 to 1.0 (left to right)
  final double width;
  
  Obstacle({
    required this.yPosition,
    required this.xPosition,
    this.width = 0.15,
  });
  
  bool checkCollision(double carX, double carY, double carWidth) {
    final carLeft = carX - carWidth / 2;
    final carRight = carX + carWidth / 2;
    final obstacleLeft = xPosition - width / 2;
    final obstacleRight = xPosition + width / 2;
    
    final horizontalOverlap = carRight > obstacleLeft && carLeft < obstacleRight;
    final verticalOverlap = (carY - 0.1) < yPosition && (carY + 0.1) > yPosition;
    
    return horizontalOverlap && verticalOverlap;
  }
}