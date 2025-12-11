import 'package:eyesgym/models/eye_state.dart';

class BlinkDetectionService {
  bool _wereBothEyesClosed = false;
  DateTime? _eyesClosedStartTime;
  
  // Tuning parameters
  static const double _eyeOpenThreshold = 0.5;
  static const double _eyeClosedThreshold = 0.2; // Stricter threshold for closing
  
  BlinkEvent? detectBlink(EyeState eyeState) {
    final now = DateTime.now();
    BlinkEvent? event;
    
    // We strictly use "Both Eyes" for the game to prevent accidental winks
    // Using a hysteresis threshold to prevent flickering
    bool areEyesClosed = eyeState.leftEyeOpenProbability < _eyeClosedThreshold && 
                         eyeState.rightEyeOpenProbability < _eyeClosedThreshold;
                         
    bool areEyesOpen = eyeState.leftEyeOpenProbability > _eyeOpenThreshold && 
                       eyeState.rightEyeOpenProbability > _eyeOpenThreshold;

    if (areEyesClosed && !_wereBothEyesClosed) {
      // Eyes just closed, start timer
      _wereBothEyesClosed = true;
      _eyesClosedStartTime = now;
      return BlinkEvent(type: BlinkType.eyesClosed, timestamp: now);
    } 
    
    if (areEyesOpen && _wereBothEyesClosed) {
      // Eyes just opened, calculate duration
      _wereBothEyesClosed = false;
      
      if (_eyesClosedStartTime != null) {
        final duration = now.difference(_eyesClosedStartTime!);
        event = BlinkEvent(
          type: BlinkType.blinkComplete, 
          timestamp: now,
          duration: duration
        );
      }
      _eyesClosedStartTime = null;
    }
    
    return event;
  }
  
  Duration getCurrentClosedDuration() {
    if (_wereBothEyesClosed && _eyesClosedStartTime != null) {
      return DateTime.now().difference(_eyesClosedStartTime!);
    }
    return Duration.zero;
  }
  
  void reset() {
    _wereBothEyesClosed = false;
    _eyesClosedStartTime = null;
  }
}

enum BlinkType { eyesClosed, blinkComplete }

class BlinkEvent {
  final BlinkType type;
  final DateTime timestamp;
  final Duration duration;
  
  BlinkEvent({
    required this.type, 
    required this.timestamp, 
    this.duration = Duration.zero
  });
}