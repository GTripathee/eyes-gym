import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:eyesgym/models/focus_mode_models.dart';
import 'package:eyesgym/models/face_detection_state.dart';
import 'package:eyesgym/services/blink_detection_service.dart';
import 'package:eyesgym/services/face_detection_service.dart';
import 'package:eyesgym/services/image_conversion_service.dart';
import 'package:eyesgym/services/storage_service.dart';
import 'package:flutter/foundation.dart';

class FocusSessionViewModel extends ChangeNotifier {
  final CameraDescription camera;
  final FaceDetectionService _faceDetectionService;
  final ImageConversionService _imageConversionService;
  final BlinkDetectionService _blinkDetectionService;
  
  late CameraController _controller;
  CameraController get controller => _controller;

  // Audio Players
  final AudioPlayer _musicPlayer = AudioPlayer(); // Background music
  final AudioPlayer _sfxPlayer = AudioPlayer();   // Success sounds (Bells)
  final AudioPlayer _cuePlayer = AudioPlayer();   // Guidance cues (Metronome)
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;
  
  FaceDetectionState _detectionState = FaceDetectionState();
  FaceDetectionState get detectionState => _detectionState;
  
  // Load the Guided Exercise by default
  final FocusSong _currentSong = FocusSong.guidedExercise();
  
  int _currentNoteIndex = 0;
  BlinkNote? get currentNote => _currentNoteIndex < _currentSong.notes.length ? _currentSong.notes[_currentNoteIndex] : null;
  
  String _feedbackMessage = "Ready?";
  String get feedbackMessage => _feedbackMessage;
  
  int _score = 0;
  int get score => _score;
  int _sessionBlinks = 0;
  
  Timer? _gameLoopTimer;
  DateTime? _sessionStartTime;
  bool _isDetecting = false;
  
  // CONFIGURATION
  static const Duration _longBlinkThreshold = Duration(milliseconds: 500);

  FocusSessionViewModel({required this.camera})
      : _faceDetectionService = FaceDetectionService(),
        _imageConversionService = ImageConversionService(),
        _blinkDetectionService = BlinkDetectionService();

  Future<void> initialize() async {
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller.initialize();
    _isInitialized = true;
    notifyListeners();
    _controller.startImageStream((image) {
      if (!_isDetecting) _processImage(image);
    });
  }

  Future<void> _processImage(CameraImage image) async {
    _isDetecting = true;
    try {
      final inputImage = _imageConversionService.convertCameraImage(image, camera);
      if (inputImage == null) return;
      final faces = await _faceDetectionService.detectFaces(inputImage);
      
      _detectionState = _detectionState.copyWith(faces: faces);
      
      if (_isSessionActive && _detectionState.eyeState != null) {
        final blinkEvent = _blinkDetectionService.detectBlink(_detectionState.eyeState!);
        
        // Success Sound Logic (Feedback)
        if (blinkEvent != null && blinkEvent.type == BlinkType.blinkComplete) {
          _handleBlinkSound(blinkEvent.duration);
        }

        _checkRhythm(blinkEvent);
      }
      notifyListeners();
    } catch (e) {
      print(e);
    } finally {
      _isDetecting = false;
    }
  }

  void _handleBlinkSound(Duration duration) {
    if (duration > _longBlinkThreshold) {
      // Feedback for Long Blink
      _sfxPlayer.play(AssetSource('audio/bell_longer.mp3'), mode: PlayerMode.lowLatency);
    } else {
      // Feedback for Short Blink
      _sfxPlayer.play(AssetSource('audio/bell_shorter.mp3'), mode: PlayerMode.lowLatency);
    }
  }

  void startSession() async {
    _isSessionActive = true;
    _score = 0;
    _currentNoteIndex = 0;
    _sessionBlinks = 0;
    _feedbackMessage = "Ready...";
    _sessionStartTime = DateTime.now();
    
    // Play Background Music
    await _musicPlayer.play(AssetSource(_currentSong.audioAssetPath));
    
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _updateLoop();
    });
    notifyListeners();
  }
  
  void _updateLoop() {
    if (!_isSessionActive) return;
    
    final now = DateTime.now();
    final elapsed = now.difference(_sessionStartTime!);
    
    // Check Song End
    if (_currentNoteIndex >= _currentSong.notes.length) {
      if (elapsed > _currentSong.notes.last.startTime + const Duration(seconds: 4)) {
        stopSession();
      }
      return;
    }

    final note = _currentSong.notes[_currentNoteIndex];
    
    // 1. Play CUE Sound at exact start of note (Guide the user)
    // We check if we are within 50ms of the start time to trigger the sound once
    double diff = (elapsed - note.startTime).inMilliseconds.toDouble();
    if (diff >= 0 && diff < 60) {
       // Play a tick/cue to tell user to act
       _cuePlayer.play(AssetSource('audio/blink.mp3'), mode: PlayerMode.lowLatency);
    }

    // 2. Update Window & Text
    if (elapsed > note.startTime + note.duration + const Duration(milliseconds: 500)) {
       _currentNoteIndex++;
       _feedbackMessage = "Relax...";
    } else if (elapsed >= note.startTime && elapsed <= note.startTime + note.duration) {
       if (note.type == NoteType.long) {
         _feedbackMessage = "HOLD BLINK...";
       } else {
         _feedbackMessage = "BLINK NOW!";
       }
    }
    notifyListeners();
  }
  
  void _checkRhythm(BlinkEvent? event) {
    if (currentNote == null) return;
    
    final now = DateTime.now();
    final elapsed = now.difference(_sessionStartTime!);
    final note = currentNote!;
    
    bool inWindow = elapsed >= note.startTime && 
                    elapsed <= note.startTime + note.duration + const Duration(milliseconds: 300);
                    
    if (inWindow) {
        if (note.type == NoteType.short && event?.type == BlinkType.blinkComplete) {
            _score += 10;
            _sessionBlinks++;
            _feedbackMessage = "Perfect!";
        } else if (note.type == NoteType.long) {
            // Logic for hold
            if (event?.type == BlinkType.blinkComplete && event!.duration > const Duration(milliseconds: 800)) {
                _score += 20;
                _sessionBlinks++;
                _feedbackMessage = "Great Hold!";
            }
        }
    }
  }

  void stopSession() {
    _isSessionActive = false;
    _gameLoopTimer?.cancel();
    _musicPlayer.stop();
    _sfxPlayer.stop();
    _cuePlayer.stop();
    StorageService().saveGameSession(_score, _sessionBlinks);
    _feedbackMessage = "Session Complete";
    notifyListeners();
  }
  
  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _controller.dispose();
    _faceDetectionService.dispose();
    _musicPlayer.dispose();
    _sfxPlayer.dispose();
    _cuePlayer.dispose();
    super.dispose();
  }
}