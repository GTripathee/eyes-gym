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
  final double progress; // 0.0 to 1.0 (start to finish)
  final double xPosition; // -1.0 to 1.0 (left to right across the road)
  final double speed; // Movement speed based on blink frequency
  final int score; // Total score from collected bonuses
  final int bonusesCollected;
  
  const CarState({
    this.progress = 0.0,
    this.xPosition = 0.0,
    this.speed = 0.0,
    this.score = 0,
    this.bonusesCollected = 0,
  });
  
  CarState copyWith({
    double? progress,
    double? xPosition,
    double? speed,
    int? score,
    int? bonusesCollected,
  }) {
    return CarState(
      progress: progress ?? this.progress,
      xPosition: xPosition ?? this.xPosition,
      speed: speed ?? this.speed,
      score: score ?? this.score,
      bonusesCollected: bonusesCollected ?? this.bonusesCollected,
    );
  }
}

class BonusItem {
  final double position; // 0.0 to 1.0 along the road
  final double lanePosition; // -1.0 to 1.0 (left to right)
  final int points;
  bool collected;
  
  BonusItem({
    required this.position,
    required this.lanePosition,
    this.points = 10,
    this.collected = false,
  });
  
  bool checkCollection(double carProgress, double carX, double collectionRange) {
    if (collected) return false;
    
    // Check if car is within collection range (both vertically and horizontally)
    final distanceFromCar = (position - carProgress).abs();
    final horizontalDistance = (lanePosition - carX).abs();
    
    return distanceFromCar < collectionRange && horizontalDistance < 0.3;
  }
}