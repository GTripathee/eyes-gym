import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:eyesgym/models/face_detection_state.dart';
import 'package:eyesgym/services/blink_detection_service.dart';
import 'package:eyesgym/services/face_detection_service.dart';
import 'package:eyesgym/services/image_conversion_service.dart';
import 'package:flutter/foundation.dart';

class GameViewModel extends ChangeNotifier {
  final CameraDescription camera;
  final FaceDetectionService _faceDetectionService;
  final ImageConversionService _imageConversionService;
  final BlinkDetectionService _blinkDetectionService;
  
  late CameraController _controller;
  CameraController get controller => _controller;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  bool _isDetecting = false;
  bool _isGameRunning = false;
  bool get isGameRunning => _isGameRunning;
  
  bool _isGameOver = false;
  bool get isGameOver => _isGameOver;
  
  bool _isGameWon = false;
  bool get isGameWon => _isGameWon;
  
  FaceDetectionState _detectionState = FaceDetectionState();
  FaceDetectionState get detectionState => _detectionState;
  
  CarState _carState = const CarState();
  CarState get carState => _carState;
  
  List<BonusItem> _bonusItems = [];
  List<BonusItem> get bonusItems => _bonusItems;
  
  Timer? _gameLoopTimer;
  DateTime? _lastFrameTime;
  DateTime? _lastBlinkTime;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  final Random _random = Random();
  
  // Game configuration
  static const double _roadLength = 1.0; // Full length of the road
  static const double _collectionRange = 0.08; // Range to collect bonuses (increased for smaller car)
  static const int _totalBonusItems = 6; // Total bonus items along the road (3x more for longer track)
  static const double _baseSpeed = 0.0003; // Base movement speed (5x faster for visible movement)
  static const double _blinkSpeedBoost = 0.00025; // Speed boost per blink (5x increase)
  static const double _continuousBlinkSpeedMultiplier = 4.0; // 4x speed boost for continuous blinking
  static const Duration _continuousBlinkThreshold = Duration(milliseconds: 2000); // 2 seconds of continuous blinking
  static const Duration _maxTimeBetweenBlinks = Duration(seconds: 5); // Max time without blinking
  
  int _consecutiveBlinkCount = 0;
  DateTime? _firstBlinkInSequence;
  
  GameViewModel({
    required this.camera,
    FaceDetectionService? faceDetectionService,
    ImageConversionService? imageConversionService,
    BlinkDetectionService? blinkDetectionService,
  })  : _faceDetectionService = faceDetectionService ?? FaceDetectionService(),
        _imageConversionService = imageConversionService ?? ImageConversionService(),
        _blinkDetectionService = blinkDetectionService ?? BlinkDetectionService();
  
  Future<void> initialize() async {
    try {
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      
      await _controller.initialize();
      _isInitialized = true;
      notifyListeners();
      
      _startImageStream();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
  
  void _startImageStream() {
    _controller.startImageStream((CameraImage image) {
      if (!_isDetecting) {
        _isDetecting = true;
        _processImage(image);
      }
    });
  }
  
  Future<void> _processImage(CameraImage image) async {
    final inputImage = _imageConversionService.convertCameraImage(image);
    
    if (inputImage == null) {
      _isDetecting = false;
      return;
    }
    
    final faces = await _faceDetectionService.detectFaces(inputImage);
    final fps = _calculateFPS();
    
    _detectionState = _detectionState.copyWith(
      faces: faces,
      fps: fps,
      frameCount: _detectionState.frameCount + 1,
    );
    
    // Process blink events for game control
    if (_isGameRunning && _detectionState.eyeState != null) {
      final blinkEvent = _blinkDetectionService.detectBlink(_detectionState.eyeState!);
      if (blinkEvent != null) {
        _handleBlinkEvent(blinkEvent);
      }
    }
    
    notifyListeners();
    _isDetecting = false;
  }
  
  void _handleBlinkEvent(BlinkEvent event) {
    final now = DateTime.now();
    
    // Only respond to both-eyes blink for forward movement
    if (event.type == BlinkType.bothEyes) {
      // Track consecutive blinks
      if (_lastBlinkTime != null && now.difference(_lastBlinkTime!).inMilliseconds < 500) {
        _consecutiveBlinkCount++;
        _firstBlinkInSequence ??= _lastBlinkTime;
      } else {
        _consecutiveBlinkCount = 1;
        _firstBlinkInSequence = now;
      }
      
      _lastBlinkTime = now;
      
      // Check if user has been blinking continuously for 2+ seconds
      double speedBoost = _blinkSpeedBoost;
      if (_firstBlinkInSequence != null && 
          now.difference(_firstBlinkInSequence!).inMilliseconds >= _continuousBlinkThreshold.inMilliseconds &&
          _consecutiveBlinkCount >= 3) {
        // Apply 4x speed multiplier for continuous blinking
        speedBoost *= _continuousBlinkSpeedMultiplier;
      }
      
      // Accelerate forward
      double currentSpeed = _carState.speed + speedBoost;
      _carState = _carState.copyWith(speed: currentSpeed);
      notifyListeners();
    }
  }
  
  double _calculateFPS() {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final diff = now.difference(_lastFrameTime!).inMilliseconds;
      if (diff > 0) {
        _lastFrameTime = now;
        return 1000 / diff;
      }
    }
    _lastFrameTime = now;
    return 0.0;
  }
  
  void startGame() {
    _isGameRunning = true;
    _isGameOver = false;
    _isGameWon = false;
    _carState = const CarState(speed: _baseSpeed, xPosition: 0.0);
    _generateBonusItems();
    _blinkDetectionService.reset();
    _lastBlinkTime = DateTime.now(); // Initialize with current time
    _consecutiveBlinkCount = 0;
    _firstBlinkInSequence = null;
    
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateGame();
    });
    
    notifyListeners();
  }
  
  void _generateBonusItems() {
    _bonusItems.clear();
    
    for (int i = 0; i < _totalBonusItems; i++) {
      // Distribute bonuses evenly along the road with some randomness
      double basePosition = (i + 1) / (_totalBonusItems + 1);
      double randomOffset = (_random.nextDouble() - 0.5) * 0.02;
      double position = (basePosition + randomOffset).clamp(0.05, 0.98);
      
      // All bonuses on center path (no horizontal variation)
      double lanePosition = 0.0;
      
      // Reduced bonus points by half
      int points = _random.nextDouble() < 0.2 ? 10 : 5;
      
      _bonusItems.add(BonusItem(
        position: position,
        lanePosition: lanePosition,
        points: points,
      ));
    }
  }
  
  void _updateGame() {
    if (!_isGameRunning || _isGameOver) return;
    
    final now = DateTime.now();
    
    // Check if too much time has passed without blinking
    if (_lastBlinkTime != null) {
      final timeSinceLastBlink = now.difference(_lastBlinkTime!);
      if (timeSinceLastBlink > _maxTimeBetweenBlinks) {
        _gameOver();
        return;
      }
    }
    
    // Calculate speed with faster decay
    double currentSpeed = _carState.speed;
    
    // Apply faster speed decay (3x faster)
    if (_lastBlinkTime != null) {
      final timeSinceLastBlink = now.difference(_lastBlinkTime!).inMilliseconds;
      // Speed decays faster if not blinking
      if (timeSinceLastBlink > 500) {
        currentSpeed = (currentSpeed - 0.000015).clamp(_baseSpeed, double.infinity);
        
        // Reset consecutive blink tracking if too much time has passed
        if (timeSinceLastBlink > 500) {
          _consecutiveBlinkCount = 0;
          _firstBlinkInSequence = null;
        }
      }
    } else {
      currentSpeed = _baseSpeed;
    }
    
    // Update progress - always move forward with current speed
    double newProgress = (_carState.progress + currentSpeed).clamp(0.0, 1.0);
    
    _carState = _carState.copyWith(
      progress: newProgress,
      speed: currentSpeed,
    );
    
    // Check for bonus collection (car stays centered)
    for (var bonus in _bonusItems) {
      if (!bonus.collected && 
          bonus.checkCollection(_carState.progress, 0.0, _collectionRange)) {
        bonus.collected = true;
        _carState = _carState.copyWith(
          score: _carState.score + bonus.points,
          bonusesCollected: _carState.bonusesCollected + 1,
        );
      }
    }
    
    // Check if reached the end
    if (_carState.progress >= 0.99) {
      _gameWon();
      return;
    }
    
    notifyListeners();
  }
  
  void _gameWon() {
    _isGameWon = true;
    _isGameOver = true;
    _isGameRunning = false;
    _gameLoopTimer?.cancel();
    notifyListeners();
  }
  
  void _gameOver() {
    _isGameOver = true;
    _isGameRunning = false;
    _gameLoopTimer?.cancel();
    notifyListeners();
  }
  
  void resetGame() {
    _isGameOver = false;
    _isGameWon = false;
    _isGameRunning = false;
    _carState = const CarState();
    _bonusItems.clear();
    _lastBlinkTime = null;
    _consecutiveBlinkCount = 0;
    _firstBlinkInSequence = null;
    _gameLoopTimer?.cancel();
    notifyListeners();
  }
  
  double getBlinkFrequency() {
    return _blinkDetectionService.getBlinkFrequency(const Duration(seconds: 10));
  }
  
  Duration? getTimeSinceLastBlink() {
    if (_lastBlinkTime == null) return null;
    return DateTime.now().difference(_lastBlinkTime!);
  }
  
  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _controller.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }
}