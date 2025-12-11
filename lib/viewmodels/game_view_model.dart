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
  DateTime? _lastBlinkTime; // For "Game Over" check
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  final Random _random = Random();
  
  // Game Physics
  static const double _roadLength = 1.0; 
  static const double _collectionRange = 0.05; 
  static const int _totalBonusItems = 10; 
  static const double _friction = 0.95; // Speed decay factor
  static const double _minSpeed = 0.0001;
  static const double _maxSpeed = 0.03; 
  
  // Blink Power Settings
  static const double _shortBlinkBoost = 0.004; 
  static const double _powerBlinkBoost = 0.015; // NITRO!
  static const Duration _powerBlinkThreshold = Duration(milliseconds: 600); // Hold for 0.6s to charge
  static const Duration _maxChargeTime = Duration(milliseconds: 2000); // 2 seconds max charge
  static const Duration _maxTimeBetweenBlinks = Duration(seconds: 8); 

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
        _processImage(image);
      }
    });
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
        // Detect Blinks
        final blinkEvent = _blinkDetectionService.detectBlink(_detectionState.eyeState!);
        
        // Handle blink completion (Open Eyes)
        if (blinkEvent != null && blinkEvent.type == BlinkType.blinkComplete) {
            _handleBlinkComplete(blinkEvent.duration);
        }
        
        // Handle charging status (Eyes currently closed)
        if (blinkEvent != null && blinkEvent.type == BlinkType.eyesClosed) {
             // Started closing
             _carState = _carState.copyWith(isCharging: true, chargeLevel: 0.0);
        } else if (_carState.isCharging) {
            // Still closing, update charge level
            final duration = _blinkDetectionService.getCurrentClosedDuration();
            double charge = (duration.inMilliseconds / _maxChargeTime.inMilliseconds).clamp(0.0, 1.0);
            _carState = _carState.copyWith(chargeLevel: charge);
        }
      }
      
      notifyListeners();
    } catch (e) {
      print("Error processing image: $e");
    } finally {
      _isDetecting = false;
    }
  }
  
  void _handleBlinkComplete(Duration duration) {
    _lastBlinkTime = DateTime.now();
    _carState = _carState.copyWith(isCharging: false, chargeLevel: 0.0);
    
    // Determine boost type based on duration
    double boost;
    if (duration > _powerBlinkThreshold) {
        // Power Blink (Nitro)
        // Calculate multiplier: longer hold = more speed (up to a limit)
        double multiplier = (duration.inMilliseconds / _powerBlinkThreshold.inMilliseconds).clamp(1.0, 3.0);
        boost = _powerBlinkBoost * multiplier;
    } else {
        // Standard Blink
        boost = _shortBlinkBoost;
    }
    
    // Apply speed
    double newSpeed = (_carState.speed + boost).clamp(0.0, _maxSpeed);
    _carState = _carState.copyWith(speed: newSpeed);
  }
  
  void startGame() {
    _isGameRunning = true;
    _isGameOver = false;
    _isGameWon = false;
    _carState = const CarState(speed: 0.0);
    _generateBonusItems();
    _blinkDetectionService.reset();
    _lastBlinkTime = DateTime.now();
    
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateGamePhysics();
    });
    
    notifyListeners();
  }
  
  void _generateBonusItems() {
    _bonusItems.clear();
    for (int i = 0; i < _totalBonusItems; i++) {
      double position = ((i + 1) / (_totalBonusItems + 1)).clamp(0.05, 0.95);
      _bonusItems.add(BonusItem(
        position: position,
        lanePosition: 0.0,
        points: 10,
      ));
    }
  }
  
  void _updateGamePhysics() {
    if (!_isGameRunning || _isGameOver) return;
    
    final now = DateTime.now();
    
    // Check Timeout
    if (_lastBlinkTime != null && now.difference(_lastBlinkTime!) > _maxTimeBetweenBlinks) {
      _gameOver();
      return;
    }
    
    // Apply Friction (Slow down car)
    double currentSpeed = _carState.speed * _friction;
    if (currentSpeed < _minSpeed) currentSpeed = 0.0;
    
    // Move Car
    double newProgress = (_carState.progress + currentSpeed).clamp(0.0, 1.0);
    
    // Update State
    _carState = _carState.copyWith(
      progress: newProgress,
      speed: currentSpeed,
    );
    
    // Check Collections
    for (var bonus in _bonusItems) {
      if (!bonus.collected && bonus.checkCollection(_carState.progress, 0.0, _collectionRange)) {
        bonus.collected = true;
        _carState = _carState.copyWith(
          score: _carState.score + bonus.points,
          bonusesCollected: _carState.bonusesCollected + 1,
        );
      }
    }
    
    // Win Condition
    if (_carState.progress >= 1.0) {
      _gameWon();
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
    _gameLoopTimer?.cancel();
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