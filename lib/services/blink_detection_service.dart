import 'package:eyesgym/models/eye_state.dart';

class BlinkDetectionService {
  bool _wasLeftEyeClosed = false;
  bool _wasRightEyeClosed = false;
  bool _wereBothEyesClosed = false;
  
  DateTime? _lastLeftBlink;
  DateTime? _lastRightBlink;
  DateTime? _lastBothBlink;
  
  int _leftBlinkCount = 0;
  int _rightBlinkCount = 0;
  int _bothBlinkCount = 0;
  
  BlinkEvent? detectBlink(EyeState eyeState) {
    final now = DateTime.now();
    BlinkEvent? event;
    
    // Detect left eye blink
    if (!eyeState.isLeftEyeOpen && eyeState.isRightEyeOpen && !_wasLeftEyeClosed) {
      _wasLeftEyeClosed = true;
      _lastLeftBlink = now;
      _leftBlinkCount++;
      event = BlinkEvent(type: BlinkType.leftEye, timestamp: now);
    } else if (eyeState.isLeftEyeOpen) {
      _wasLeftEyeClosed = false;
    }
    
    // Detect right eye blink
    if (!eyeState.isRightEyeOpen && eyeState.isLeftEyeOpen && !_wasRightEyeClosed) {
      _wasRightEyeClosed = true;
      _lastRightBlink = now;
      _rightBlinkCount++;
      event = BlinkEvent(type: BlinkType.rightEye, timestamp: now);
    } else if (eyeState.isRightEyeOpen) {
      _wasRightEyeClosed = false;
    }
    
    // Detect both eyes blink
    if (eyeState.isBothEyesClosed && !_wereBothEyesClosed) {
      _wereBothEyesClosed = true;
      _lastBothBlink = now;
      _bothBlinkCount++;
      event = BlinkEvent(type: BlinkType.bothEyes, timestamp: now);
    } else if (eyeState.isBothEyesOpen) {
      _wereBothEyesClosed = false;
    }
    
    return event;
  }
  
  double getBlinkFrequency(Duration window) {
    final now = DateTime.now();
    final windowStart = now.subtract(window);
    
    int recentBlinks = 0;
    if (_lastBothBlink != null && _lastBothBlink!.isAfter(windowStart)) {
      recentBlinks++;
    }
    
    return recentBlinks / window.inSeconds;
  }
  
  void reset() {
    _leftBlinkCount = 0;
    _rightBlinkCount = 0;
    _bothBlinkCount = 0;
  }
}

enum BlinkType { leftEye, rightEye, bothEyes }

class BlinkEvent {
  final BlinkType type;
  final DateTime timestamp;
  
  BlinkEvent({required this.type, required this.timestamp});
}