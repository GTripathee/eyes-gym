import 'package:camera/camera.dart';
import 'package:eyesgym/models/face_detection_state.dart';
import 'package:eyesgym/services/face_detection_service.dart';
import 'package:eyesgym/services/image_conversion_service.dart';
import 'package:flutter/foundation.dart';

class CameraViewModel extends ChangeNotifier {
  final CameraDescription camera;
  final FaceDetectionService _faceDetectionService;
  final ImageConversionService _imageConversionService;
  
  late CameraController _controller;
  CameraController get controller => _controller;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  bool _isDetecting = false;
  
  FaceDetectionState _detectionState = FaceDetectionState();
  FaceDetectionState get detectionState => _detectionState;
  
  DateTime? _lastFrameTime;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  CameraViewModel({
    required this.camera,
    FaceDetectionService? faceDetectionService,
    ImageConversionService? imageConversionService,
  })  : _faceDetectionService = faceDetectionService ?? FaceDetectionService(),
        _imageConversionService = imageConversionService ?? ImageConversionService();
  
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
    // FIX: Pass the 'camera' description here to access sensorOrientation
    final inputImage = _imageConversionService.convertCameraImage(image, camera);
    
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
    
    notifyListeners();
    _isDetecting = false;
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
  
  @override
  void dispose() {
    _controller.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }
}