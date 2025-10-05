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
  
  FaceDetectionState _detectionState = FaceDetectionState();
  FaceDetectionState get detectionState => _detectionState;
  
  CarState _carState = const CarState();
  CarState get carState => _carState;
  
  List<Obstacle> _obstacles = [];
  List<Obstacle> get obstacles => _obstacles;
  
  Timer? _gameLoopTimer;
  DateTime? _lastFrameTime;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  final Random _random = Random();
  
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
    switch (event.type) {
      case BlinkType.leftEye:
        // Steer left
        _carState = _carState.copyWith(
          xPosition: (_carState.xPosition - 0.2).clamp(-0.8, 0.8),
        );
        break;
      case BlinkType.rightEye:
        // Steer right
        _carState = _carState.copyWith(
          xPosition: (_carState.xPosition + 0.2).clamp(-0.8, 0.8),
        );
        break;
      case BlinkType.bothEyes:
        // Accelerate
        _carState = _carState.copyWith(
          speed: (_carState.speed + 10.0).clamp(0.0, 100.0),
        );
        break;
    }
    notifyListeners();
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
    _carState = const CarState(speed: 20.0);
    _obstacles.clear();
    _blinkDetectionService.reset();
    
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _updateGame();
    });
    
    notifyListeners();
  }
  
  void _updateGame() {
    if (!_isGameRunning || _isGameOver) return;
    
    // Decrease speed gradually
    double newSpeed = (_carState.speed - 0.5).clamp(0.0, 100.0);
    
    // Update distance
    double newDistance = _carState.distance + (newSpeed / 100.0);
    
    // Update score
    int newScore = (newDistance * 10).toInt();
    
    _carState = _carState.copyWith(
      speed: newSpeed,
      distance: newDistance,
      score: newScore,
    );
    
    // Update obstacles
    for (var obstacle in _obstacles) {
      obstacle.yPosition += 0.02 + (_carState.speed / 5000);
    }
    
    // Remove off-screen obstacles
    _obstacles.removeWhere((obstacle) => obstacle.yPosition > 1.2);
    
    // Add new obstacles randomly
    if (_obstacles.length < 3 && _random.nextDouble() < 0.05) {
      _obstacles.add(Obstacle(
        yPosition: -0.1,
        xPosition: (_random.nextDouble() * 1.6) - 0.8,
      ));
    }
    
    // Check collisions
    for (var obstacle in _obstacles) {
      if (obstacle.checkCollision(_carState.xPosition, 0.8, 0.1)) {
        _gameOver();
        return;
      }
    }
    
    // Game over if speed reaches 0
    if (_carState.speed <= 0) {
      _gameOver();
      return;
    }
    
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
    _isGameRunning = false;
    _carState = const CarState();
    _obstacles.clear();
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