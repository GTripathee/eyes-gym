import 'package:eyesgym/models/eye_state.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum DifficultyLevel { easy, medium, hard }

class FaceDetectionState {
  final List<Face> faces;
  final bool hasFaceDetected;
  final EyeState? eyeState;
  final double? headEulerAngleZ; // For steering (Head Tilt)
  final double fps;
  final int frameCount;

  FaceDetectionState({
    this.faces = const [],
    this.fps = 0.0,
    this.frameCount = 0,
  })  : hasFaceDetected = faces.isNotEmpty,
        headEulerAngleZ = faces.isNotEmpty ? faces.first.headEulerAngleZ : 0.0,
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
  final double xPosition; // -1.0 (Left) to 1.0 (Right)
  final double speed; 
  final int score; 
  final int bonusesCollected;
  final bool isCharging; 
  final double chargeLevel;
  final bool isCrashed; // New: For obstacle collision
  
  const CarState({
    this.progress = 0.0,
    this.xPosition = 0.0,
    this.speed = 0.0,
    this.score = 0,
    this.bonusesCollected = 0,
    this.isCharging = false,
    this.chargeLevel = 0.0,
    this.isCrashed = false,
  });
  
  CarState copyWith({
    double? progress,
    double? xPosition,
    double? speed,
    int? score,
    int? bonusesCollected,
    bool? isCharging,
    double? chargeLevel,
    bool? isCrashed,
  }) {
    return CarState(
      progress: progress ?? this.progress,
      xPosition: xPosition ?? this.xPosition,
      speed: speed ?? this.speed,
      score: score ?? this.score,
      bonusesCollected: bonusesCollected ?? this.bonusesCollected,
      isCharging: isCharging ?? this.isCharging,
      chargeLevel: chargeLevel ?? this.chargeLevel,
      isCrashed: isCrashed ?? this.isCrashed,
    );
  }
}

class RoadItem {
  final double position; // 0.0 to 1.0 (Y axis)
  final double lanePosition; // -1.0 to 1.0 (X axis)
  
  RoadItem({required this.position, required this.lanePosition});
}

class BonusItem extends RoadItem {
  final int points;
  bool collected;
  
  BonusItem({
    required double position,
    required double lanePosition,
    this.points = 10,
    this.collected = false,
  }) : super(position: position, lanePosition: lanePosition);
  
  bool checkCollection(double carProgress, double carX, double range) {
    if (collected) return false;
    
    // Y Axis Check:
    // 'range' is now 0.015 (Very small).
    // The item MUST be within this tiny slice of the track to count.
    final dy = (position - carProgress).abs();
    
    // X Axis Check:
    // Car width approx 0.25 of lane width.
    final dx = (lanePosition - carX).abs();
    
    // Hitbox: Must be vertically aligned (dy < range) AND horizontally close (dx < 0.3)
    return dy < range && dx < 0.3; 
  }
}

class ObstacleItem extends RoadItem {
  bool hit;
  
  ObstacleItem({
    required double position,
    required double lanePosition,
    this.hit = false,
  }) : super(position: position, lanePosition: lanePosition);
  
  bool checkCollision(double carProgress, double carX, double range) {
    if (hit) return false;
    final dy = (position - carProgress).abs();
    final dx = (lanePosition - carX).abs();
    
    // Obstacles have slightly tighter horizontal width (0.25) so you can dodge them
    return dy < range && dx < 0.25; 
  }
}