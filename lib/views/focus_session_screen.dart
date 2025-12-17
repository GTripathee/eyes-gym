import 'package:camera/camera.dart';
import 'package:eyesgym/models/focus_mode_models.dart';
import 'package:eyesgym/viewmodels/focus_session_view_model.dart';
import 'package:flutter/material.dart';

class FocusSessionScreen extends StatefulWidget {
  final CameraDescription camera;
  const FocusSessionScreen({Key? key, required this.camera}) : super(key: key);

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> {
  late FocusSessionViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = FocusSessionViewModel(camera: widget.camera);
    _viewModel.addListener(() => setState(() {}));
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_viewModel.isInitialized) {
      return const Scaffold(backgroundColor: Color(0xFF121212), body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // 1. Central Visual
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _getVisualSize(),
              height: _getVisualSize(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getVisualColor().withOpacity(0.2),
                border: Border.all(color: _getVisualColor(), width: 2),
                boxShadow: [BoxShadow(color: _getVisualColor().withOpacity(0.5), blurRadius: 40)],
              ),
              child: Center(
                child: Icon(
                  _viewModel.detectionState.eyeState?.isBothEyesClosed == true 
                      ? Icons.visibility_off 
                      : Icons.visibility,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
          
          // 2. UI Overlay
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text("Points: ${_viewModel.score}", style: const TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Feedback Text
                Text(
                  _viewModel.feedbackMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 32, 
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: _getVisualColor(), blurRadius: 20)],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Start Button
                if (!_viewModel.isSessionActive)
                  ElevatedButton.icon(
                    onPressed: _viewModel.startSession,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("START THERAPY"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                  
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getVisualSize() {
      // Get larger when "Blink Now" is active to draw attention
      if (_viewModel.currentNote != null && _viewModel.feedbackMessage.contains("BLINK")) {
          return 250.0;
      }
      return 150.0;
  }
  
  Color _getVisualColor() {
      final note = _viewModel.currentNote;
      if (note != null) {
          // Purple for Hold (Long), Cyan for Tap (Short)
          return note.type == NoteType.long ? Colors.purpleAccent : Colors.cyanAccent;
      }
      return Colors.grey;
  }
}