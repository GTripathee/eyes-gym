import 'package:camera/camera.dart';
import 'package:eyesgym/viewmodels/game_view_model.dart';
import 'package:eyesgym/views/widgets/road_painter.dart';
import 'package:flutter/material.dart';

class GameScreen extends StatefulWidget {
  final CameraDescription camera;
  
  const GameScreen({Key? key, required this.camera}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = GameViewModel(camera: widget.camera);
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.initialize();
  }
  
  void _onViewModelChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_viewModel.errorMessage != null) {
      return _buildErrorView(_viewModel.errorMessage!);
    }
    
    if (!_viewModel.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Stack(
      children: [
        _buildGameView(),
        _buildCameraPreview(),
        _buildGameOverlay(),
      ],
    );
  }
  
  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text('Error: $error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGameView() {
    return Container(
      color: Colors.grey[300],
      child: CustomPaint(
        painter: RoadPainter(
          carState: _viewModel.carState,
          obstacles: _viewModel.obstacles,
        ),
        child: Container(),
      ),
    );
  }
  
  Widget _buildCameraPreview() {
    return Positioned(
      top: 40,
      right: 20,
      child: Container(
        width: 120,
        height: 160,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CameraPreview(_viewModel.controller),
        ),
      ),
    );
  }
  
  Widget _buildGameOverlay() {
    return SafeArea(
      child: Column(
        children: [
          _buildStatusBar(),
          const Spacer(),
          if (!_viewModel.isGameRunning && !_viewModel.isGameOver)
            _buildStartButton(),
          if (_viewModel.isGameOver)
            _buildGameOverScreen(),
          if (_viewModel.isGameRunning)
            _buildInstructions(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
  
  Widget _buildStatusBar() {
    final state = _viewModel.detectionState;
    
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score: ${_viewModel.carState.score}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Speed: ${_viewModel.carState.speed.toInt()} km/h',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: state.hasFaceDetected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
            child: Icon(
              state.hasFaceDetected ? Icons.face : Icons.face_unlock_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStartButton() {
    final hasFace = _viewModel.detectionState.hasFaceDetected;
    
    return Container(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: hasFace ? () => _viewModel.startGame() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'START GAME',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          if (!hasFace)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '⚠️ Position your face in the camera',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildGameOverScreen() {
    return Container(
      margin: const EdgeInsets.all(30),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'GAME OVER!',
            style: TextStyle(
              color: Colors.red,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Final Score: ${_viewModel.carState.score}',
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => _viewModel.resetGame(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: const Text('PLAY AGAIN', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstructions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Text(
            '🚗 Game Controls',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '👁️ Left Eye Blink = Steer LEFT',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            '👁️ Right Eye Blink = Steer RIGHT',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            '😊 Both Eyes Blink = ACCELERATE',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}