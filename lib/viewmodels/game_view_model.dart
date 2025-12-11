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
  
  // Difficulty State
  DifficultyLevel _difficulty = DifficultyLevel.medium;
  DifficultyLevel get difficulty => _difficulty;
  
  FaceDetectionState _detectionState = FaceDetectionState();
  FaceDetectionState get detectionState => _detectionState;
  
  CarState _carState = const CarState();
  CarState get carState => _carState;
  
  List<BonusItem> _bonusItems = [];
  List<BonusItem> get bonusItems => _bonusItems;
  
  List<ObstacleItem> _obstacles = [];
  List<ObstacleItem> get obstacles => _obstacles;
  
  Timer? _gameLoopTimer;
  DateTime? _lastFrameTime;
  DateTime? _lastBlinkTime;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  final Random _random = Random();
  
  // --- TUNING CONSTANTS ---
  // Game Length: Multiplied base items by 3x (from ~10 to 30)
  static const int _baseTotalBonusItems = 30; 
  static const double _maxSpeed = 0.03; 
  static const Duration _powerBlinkThreshold = Duration(milliseconds: 600); 
  static const Duration _maxTimeBetweenBlinks = Duration(seconds: 8); 
  static const double _collectionRange = 0.05; 
  // Steering Sensitivity: Angle required for max tilt
  static const double _maxTiltDegrees = 30.0; 

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
      if (!_isDetecting) _processImage(image);
    });
  }
  
  void setDifficulty(DifficultyLevel level) {
    _difficulty = level;
    notifyListeners();
  }

  Future<void> _processImage(CameraImage image) async {
    _isDetecting = true;
    try {
      final inputImage = _imageConversionService.convertCameraImage(image);
      if (inputImage == null) return;
      
      final faces = await _faceDetectionService.detectFaces(inputImage);
      
      _detectionState = _detectionState.copyWith(
        faces: faces,
        frameCount: _detectionState.frameCount + 1,
      );
      
      if (_isGameRunning && _detectionState.eyeState != null) {
        // 1. Handle Steering (Head Tilt)
        if (_difficulty != DifficultyLevel.easy) {
            double headTilt = _detectionState.headEulerAngleZ ?? 0.0;
            // Map tilt (-maxTilt to maxTilt) to X position (-1.0 to 1.0)
            double targetX = (headTilt / _maxTiltDegrees).clamp(-1.0, 1.0) * -1.0; 
            
            // Hard mode steering is more responsive (less smooth/forgiving)
            double lerpFactor = _difficulty == DifficultyLevel.hard ? 0.3 : 0.1;
            double newX = _carState.xPosition + (targetX - _carState.xPosition) * lerpFactor;
            _carState = _carState.copyWith(xPosition: newX);
        } else {
             _carState = _carState.copyWith(xPosition: 0.0);
        }

        // 2. Handle Blinking
        final blinkEvent = _blinkDetectionService.detectBlink(_detectionState.eyeState!);
        
        if (blinkEvent != null && blinkEvent.type == BlinkType.blinkComplete) {
            _handleBlinkComplete(blinkEvent.duration);
        } else if (blinkEvent != null && blinkEvent.type == BlinkType.eyesClosed) {
             _carState = _carState.copyWith(isCharging: true, chargeLevel: 0.0);
        } else if (_carState.isCharging) {
            final duration = _blinkDetectionService.getCurrentClosedDuration();
            double charge = (duration.inMilliseconds / 2000).clamp(0.0, 1.0);
            _carState = _carState.copyWith(chargeLevel: charge);
        }
      }
      
      notifyListeners();
    } catch (e) {
      print("Error: $e");
    } finally {
      _isDetecting = false;
    }
  }
  
  void _handleBlinkComplete(Duration duration) {
    _lastBlinkTime = DateTime.now();
    _carState = _carState.copyWith(isCharging: false, chargeLevel: 0.0);
    
    double baseBoost = 0.004;
    // Difficulty influences the base speed gain
    if (_difficulty == DifficultyLevel.easy) baseBoost = 0.006; 
    if (_difficulty == DifficultyLevel.hard) baseBoost = 0.002; // Must blink more frequently for same speed
    
    double boost = duration > _powerBlinkThreshold 
        ? baseBoost * 4.0 // Nitro Boost Multiplier
        : baseBoost;
        
    double newSpeed = (_carState.speed + boost).clamp(0.0, _maxSpeed);
    _carState = _carState.copyWith(speed: newSpeed);
  }

  void startGame() {
    _isGameRunning = true;
    _isGameOver = false;
    _isGameWon = false;
    _carState = const CarState(speed: 0.0);
    _generateLevel();
    _blinkDetectionService.reset();
    _lastBlinkTime = DateTime.now();
    
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateGamePhysics();
    });
    
    notifyListeners();
  }
  
  void _generateLevel() {
    _bonusItems.clear();
    _obstacles.clear();
    
    // --- 1. Generate Bonuses (Game Length) ---
    int bonusCount = _baseTotalBonusItems;
    if (_difficulty == DifficultyLevel.easy) bonusCount = (_baseTotalBonusItems * 1.5).toInt(); // Easier to win
    
    for (int i = 0; i < bonusCount; i++) {
      // Space items evenly across the 0.0 to 1.0 track length
      double pos = ((i + 1) / (bonusCount + 1)).clamp(0.05, 0.95);
      
      // Random X position based on difficulty
      double lane = 0.0;
      if (_difficulty == DifficultyLevel.medium) {
          lane = (_random.nextDouble() * 1.2) - 0.6; // Wider variance in lane
      } else if (_difficulty == DifficultyLevel.hard) {
          lane = (_random.nextDouble() * 1.6) - 0.8; // Max variance
      }
          
      _bonusItems.add(BonusItem(position: pos, lanePosition: lane));
    }
    
    // --- 2. Generate Obstacles (Obstacle Fix & Difficulty) ---
    int obsCount = 0;
    if (_difficulty == DifficultyLevel.medium) obsCount = 20; 
    if (_difficulty == DifficultyLevel.hard) obsCount = 40; // Double the density for Hard
    
    for (int i = 0; i < obsCount; i++) {
        // Position items evenly across the track length, ensuring they don't spawn too close
        double pos = (_random.nextDouble() * 0.9) + 0.05; 
        double lane = (_random.nextDouble() * 1.6) - 0.8;
        
        // Prevent placing obstacle too close to existing bonus or obstacle
        bool tooClose = _bonusItems.any((b) => (b.position - pos).abs() < 0.02) ||
                        _obstacles.any((o) => (o.position - pos).abs() < 0.04);
        
        if (!tooClose) {
            _obstacles.add(ObstacleItem(position: pos, lanePosition: lane));
        }
    }
  }
  
  void _updateGamePhysics() {
    if (!_isGameRunning || _isGameOver) return;
    final now = DateTime.now();

    // 1. Friction (Decay - KEY DIFFERENCE)
    double friction = 0.97;
    if (_difficulty == DifficultyLevel.easy) friction = 0.985; // Very slow decay
    if (_difficulty == DifficultyLevel.medium) friction = 0.97; // Moderate decay
    if (_difficulty == DifficultyLevel.hard) friction = 0.95; // Fast decay - forces continuous blinking
    
    double currentSpeed = _carState.speed * friction;
    
    // 2. Obstacle Collisions
    bool crash = false;
    for (var obs in _obstacles) {
        if (!obs.hit && obs.checkCollision(_carState.progress, _carState.xPosition, _collectionRange)) {
            obs.hit = true;
            crash = true;
            
            if (_difficulty == DifficultyLevel.medium) {
                currentSpeed *= 0.5; // Moderate speed penalty
            } else if (_difficulty == DifficultyLevel.hard) {
                currentSpeed = 0.0; // Complete halt for 0.5s
            }
        }
    }
    
    if (crash) {
        _carState = _carState.copyWith(isCrashed: true);
        Timer(const Duration(milliseconds: 500), () {
             _carState = _carState.copyWith(isCrashed: false);
        });
    }

    // 3. Movement
    double newProgress = (_carState.progress + currentSpeed).clamp(0.0, 1.0);
    _carState = _carState.copyWith(progress: newProgress, speed: currentSpeed);

    // 4. Bonus Collection
    for (var bonus in _bonusItems) {
      if (!bonus.collected && bonus.checkCollection(_carState.progress, _carState.xPosition, _collectionRange)) {
        bonus.collected = true;
        _carState = _carState.copyWith(
          score: _carState.score + bonus.points,
          bonusesCollected: _carState.bonusesCollected + 1,
        );
      }
    }

    // 5. Win/Lose
    if (_carState.progress >= 1.0) _gameWon();
    // Timeout logic...
    if (_lastBlinkTime != null && now.difference(_lastBlinkTime!) > _maxTimeBetweenBlinks) {
        _gameOver();
    }
    
    notifyListeners();
  }
  
  void _gameWon() { _isGameWon = true; _isGameOver = true; _isGameRunning = false; _gameLoopTimer?.cancel(); notifyListeners(); }
  void _gameOver() { _isGameOver = true; _isGameRunning = false; _gameLoopTimer?.cancel(); notifyListeners(); }
  void resetGame() { 
    _isGameOver = false; _isGameWon = false; _isGameRunning = false; 
    _carState = const CarState(); 
    _gameLoopTimer?.cancel(); 
    _blinkDetectionService.reset();
    notifyListeners(); 
  }
  
  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _controller.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }
}