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
  
  // --- CONFIGURATION ---
  static const double _trackLengthScale = 3.0; 
  static const int _baseBonusCount = 10; 
  static const int _baseObstacleCount = 5;

  static const double _maxSpeed = 0.03; 
  static const Duration _powerBlinkThreshold = Duration(milliseconds: 600); 
  static const Duration _maxTimeBetweenBlinks = Duration(seconds: 8); 
  
  // FIX: Reduced range significantly so items touch car before collecting
  static const double _collectionRange = 0.015; 
  static const double _maxTiltDegrees = 25.0; 

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
        // --- STEERING ---
        if (_difficulty == DifficultyLevel.hard) {
            double headTilt = _detectionState.headEulerAngleZ ?? 0.0;
            double targetX = (headTilt / _maxTiltDegrees).clamp(-1.0, 1.0) * -1.0; 
            double newX = _carState.xPosition + (targetX - _carState.xPosition) * 0.2;
            _carState = _carState.copyWith(xPosition: newX);
        } else {
             // Auto-center (Drift back to middle)
             double newX = _carState.xPosition * 0.9; 
             _carState = _carState.copyWith(xPosition: newX);
        }

        // --- BLINKING ---
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
    
    double baseBoost = 0.005;
    if (_difficulty == DifficultyLevel.easy) baseBoost = 0.007; 
    if (_difficulty == DifficultyLevel.hard) baseBoost = 0.003; 
    
    double boost = duration > _powerBlinkThreshold ? baseBoost * 3.5 : baseBoost;
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
    
    int totalBonuses = (_baseBonusCount * _trackLengthScale).toInt();
    int totalObstacles = (_baseObstacleCount * _trackLengthScale).toInt();

    // Generate Bonuses
    for (int i = 0; i < totalBonuses; i++) {
      double pos = ((i + 1) / (totalBonuses + 2)).clamp(0.02, 0.98);
      double lane = _difficulty == DifficultyLevel.hard 
          ? (_random.nextDouble() * 1.4) - 0.7 
          : 0.0; 
      _bonusItems.add(BonusItem(position: pos, lanePosition: lane));
    }
    
    // Generate Obstacles (Hard Only)
    if (_difficulty == DifficultyLevel.hard) {
        int count = (totalObstacles * 1.5).toInt();
        for (int i = 0; i < count; i++) {
            double pos = (_random.nextDouble() * 0.9) + 0.05;
            double lane = (_random.nextDouble() * 1.6) - 0.8;
            if (!_isTooClose(pos, lane)) {
                _obstacles.add(ObstacleItem(position: pos, lanePosition: lane));
            }
        }
    }
  }
  
  bool _isTooClose(double pos, double lane) {
      for (var b in _bonusItems) {
          if ((b.position - pos).abs() < 0.05 && (b.lanePosition - lane).abs() < 0.2) {
              return true;
          }
      }
      return false;
  }
  
  void _updateGamePhysics() {
    if (!_isGameRunning || _isGameOver) return;
    final now = DateTime.now();

    // 1. Calculate Friction
    double friction = 0.98;
    if (_difficulty == DifficultyLevel.medium) friction = 0.96;
    if (_difficulty == DifficultyLevel.hard) friction = 0.93;
    
    double currentSpeed = _carState.speed * friction;
    double progressDelta = currentSpeed / _trackLengthScale;
    
    // 2. OBSTACLE COLLISION (Hard Mode Logic)
    bool crash = false;
    if (_difficulty == DifficultyLevel.hard) {
        for (var obs in _obstacles) {
            // FIX: Using tighter range for collision too
            if (!obs.hit && obs.checkCollision(_carState.progress, _carState.xPosition, _collectionRange)) {
                obs.hit = true;
                crash = true;
                
                // --- PUNISHMENT ---
                // 1. Instant Stop
                currentSpeed = 0.0; 
                
                // 2. Knockback (Push Back Progress)
                // We push back by ~2% of the total track.
                // Since progressDelta is usually +0.001, -0.02 is a "Thud" backwards.
                progressDelta = -0.02; 
            }
        }
    }
    
    if (crash) {
        _carState = _carState.copyWith(isCrashed: true);
        Timer(const Duration(milliseconds: 500), () {
             _carState = _carState.copyWith(isCrashed: false);
        });
    }

    // 3. Update Position
    // We sum the normal movement + any crash knockback
    double newProgress = (_carState.progress + progressDelta).clamp(0.0, 1.0);
    
    _carState = _carState.copyWith(
      progress: newProgress,
      speed: currentSpeed, // If crashed, this is 0.0
    );

    // 4. BONUS COLLECTION (Tighter Hitbox)
    for (var bonus in _bonusItems) {
      if (!bonus.collected && bonus.checkCollection(_carState.progress, _carState.xPosition, _collectionRange)) {
        bonus.collected = true;
        _carState = _carState.copyWith(
          score: _carState.score + bonus.points,
          bonusesCollected: _carState.bonusesCollected + 1,
        );
      }
    }

    // 5. End Game Checks
    if (_carState.progress >= 0.99) _gameWon();
    
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