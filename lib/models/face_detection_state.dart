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
  final double progress; 
  final double xPosition; 
  final double speed; 
  final int score; 
  final int bonusesCollected;
  final bool isCharging; // Visual feedback for holding blink
  final double chargeLevel; // 0.0 to 1.0
  
  const CarState({
    this.progress = 0.0,
    this.xPosition = 0.0,
    this.speed = 0.0,
    this.score = 0,
    this.bonusesCollected = 0,
    this.isCharging = false,
    this.chargeLevel = 0.0,
  });
  
  CarState copyWith({
    double? progress,
    double? xPosition,
    double? speed,
    int? score,
    int? bonusesCollected,
    bool? isCharging,
    double? chargeLevel,
  }) {
    return CarState(
      progress: progress ?? this.progress,
      xPosition: xPosition ?? this.xPosition,
      speed: speed ?? this.speed,
      score: score ?? this.score,
      bonusesCollected: bonusesCollected ?? this.bonusesCollected,
      isCharging: isCharging ?? this.isCharging,
      chargeLevel: chargeLevel ?? this.chargeLevel,
    );
  }
}

class BonusItem {
  final double position; 
  final double lanePosition; 
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
    final distanceFromCar = (position - carProgress).abs();
    // Simplified logic: Since car is always center (0.0), we check proximity
    return distanceFromCar < collectionRange;
  }
}