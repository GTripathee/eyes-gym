import 'package:camera/camera.dart';
import 'package:eyesgym/models/face_detection_state.dart';
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
          bonusItems: _viewModel.bonusItems,
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
            _buildStartScreen(),
          if (_viewModel.isGameOver)
            _buildGameOverScreen(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
  
  Widget _buildStatusBar() {
    final state = _viewModel.detectionState;
    final progress = _viewModel.carState.progress;
    
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Score: ${_viewModel.carState.score}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Bonuses: ${_viewModel.carState.bonusesCollected}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey[600],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.75 ? Colors.green : 
                        progress > 0.5 ? Colors.blue :
                        progress > 0.25 ? Colors.orange : Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Progress: ${(progress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
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
  
  Widget _buildStartScreen() {
    final hasFace = _viewModel.detectionState.hasFaceDetected;
    
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🏁 Eye Race Challenge',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // Difficulty Selector
          const Text('Select Difficulty:', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               _buildDifficultyBtn(DifficultyLevel.easy, "EASY", Colors.green),
               const SizedBox(width: 8),
               _buildDifficultyBtn(DifficultyLevel.medium, "MED", Colors.blue),
               const SizedBox(width: 8),
               _buildDifficultyBtn(DifficultyLevel.hard, "HARD", Colors.red),
            ],
          ),
          
          const SizedBox(height: 20),
          _buildInstructions(),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: hasFace ? () => _viewModel.startGame() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              disabledBackgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'START RACE',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 15),
          if (!hasFace)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Position your face in camera',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDifficultyBtn(DifficultyLevel level, String label, Color color) {
    final isSelected = _viewModel.difficulty == level;
    return GestureDetector(
        onTap: () => _viewModel.setDifficulty(level),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
            ),
            child: Text(label, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ),
    );
  }
  
  Widget _buildInstructions() {
    String steerText = _viewModel.difficulty == DifficultyLevel.easy
          ? "Auto-steering enabled" 
          : "Tilt head Left/Right to steer";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Column(
          children: [
              Text("👀 Blink to Move", style: TextStyle(color: Colors.white70)),
              Text("😑 Hold blink for NITRO", style: TextStyle(color: Colors.white70)),
              Text("🤕 $steerText", style: TextStyle(color: Colors.amber)),
          ],
      ),
    );
  }
  
  Widget _buildInstructionRow(String emoji, String text) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildGameOverScreen() {
    final isWon = _viewModel.isGameWon;
    
    return Container(
      margin: const EdgeInsets.all(30),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWon ? Colors.green : Colors.red,
          width: 3,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isWon ? '🎉 CONGRATULATIONS!' : '😔 GAME OVER',
            style: TextStyle(
              color: isWon ? Colors.green : Colors.red,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isWon ? 'You reached the finish line!' : 'No blinks detected for 5 seconds!',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          _buildStatRow('Final Score', '${_viewModel.carState.score}', Colors.amber),
          const SizedBox(height: 10),
          _buildStatRow('Bonuses Collected', '${_viewModel.carState.bonusesCollected}', Colors.yellow),
          const SizedBox(height: 10),
          _buildStatRow('Progress', '${(_viewModel.carState.progress * 100).toInt()}%', Colors.blue),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => _viewModel.resetGame(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'PLAY AGAIN',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}