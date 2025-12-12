import 'package:camera/camera.dart';
import 'package:eyesgym/viewmodels/game_view_model.dart';
import 'package:eyesgym/models/face_detection_state.dart';
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
    if (mounted) setState(() {});
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
    return Center(child: Text('Error: $error'));
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
    // Only show camera when game is running to reduce distraction, or keep always
    return Positioned(
      top: 50,
      right: 20,
      child: Opacity(
        opacity: 0.8,
        child: Container(
          width: 100,
          height: 133,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CameraPreview(_viewModel.controller),
          ),
        ),
      ),
    );
  }
  
  Widget _buildGameOverlay() {
    return SafeArea(
      child: Stack(
        children: [
          // 1. Status Bar (Score/Progress)
          Column(
            children: [
              _buildStatusBar(),
              const Spacer(),
            ],
          ),
          
          // 2. Exit Button (Top Left)
          if (_viewModel.isGameRunning)
            Positioned(
              top: 10,
              left: 10,
              child: _buildExitButton(),
            ),

          // 3. Center Screens (Start / Game Over)
          Center(
             child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_viewModel.isGameRunning && !_viewModel.isGameOver)
                    _buildStartScreen(),
                  if (_viewModel.isGameOver)
                    _buildGameOverScreen(),
                ],
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildExitButton() {
    return IconButton(
      onPressed: () => _showExitDialog(),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 24),
      ),
    );
  }

  Future<void> _showExitDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false, // User must choose
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Game?'),
          content: const Text('Do you want to quit current run and go back to menu?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Quit', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _viewModel.resetGame(); // This resets state and stops game loop
              },
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildStatusBar() {
    // If not running, hide status bar or keep it? 
    // Usually hide it on start screen
    if (!_viewModel.isGameRunning && !_viewModel.isGameOver) return const SizedBox.shrink();

    final state = _viewModel.detectionState;
    final progress = _viewModel.carState.progress;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 10, 20, 0), // Left padding for Exit Button
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('⭐ ${_viewModel.carState.score}', 
                             style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 15),
                        Text('${(progress * 100).toInt()}%', 
                             style: const TextStyle(color: Colors.white, fontSize: 18)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey[700],
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Face Icon Indicator
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: state.hasFaceDetected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
            child: Icon(
              state.hasFaceDetected ? Icons.face : Icons.face_unlock_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStartScreen() {
    final hasFace = _viewModel.detectionState.hasFaceDetected;
    
    return Container(
      width: 320, // Limit width for better layout on tablets
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏁 Eye Race', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Select Difficulty:', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          
          FittedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 _buildDifficultyBtn(DifficultyLevel.easy, "EASY", Colors.green),
                 const SizedBox(width: 8),
                 _buildDifficultyBtn(DifficultyLevel.medium, "MED", Colors.blue),
                 const SizedBox(width: 8),
                 _buildDifficultyBtn(DifficultyLevel.hard, "HARD", Colors.red),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          _buildInstructions(),
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: hasFace ? () => _viewModel.startGame() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              disabledBackgroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('START RACE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          
          if (!hasFace)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '⚠️ Face not detected',
                style: TextStyle(color: Colors.orange[300], fontWeight: FontWeight.bold),
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
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? Colors.white : color.withOpacity(0.5), width: 2),
                boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)] : [],
            ),
            child: Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
    );
  }

  Widget _buildInstructions() {
    String steerText = _viewModel.difficulty == DifficultyLevel.hard 
        ? "Tilt Head to Steer" 
        : "Auto-Steering On";
        
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildInstructionRow('👀', 'Blink to Move'),
          const SizedBox(height: 8),
          _buildInstructionRow('🔥', 'Hold Blink for Boost'),
          const SizedBox(height: 8),
          _buildInstructionRow('🎮', steerText),
        ],
      ),
    );
  }
  
  Widget _buildInstructionRow(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ],
    );
  }
  
  Widget _buildGameOverScreen() {
    final isWon = _viewModel.isGameWon;
    return Container(
      width: 300,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isWon ? Colors.green : Colors.red, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isWon ? Icons.emoji_events : Icons.mood_bad, 
               size: 60, color: isWon ? Colors.amber : Colors.red),
          const SizedBox(height: 16),
          Text(isWon ? 'VICTORY!' : 'GAME OVER', 
               style: TextStyle(color: isWon ? Colors.green : Colors.red, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(isWon ? 'Eye Workout Complete!' : 'Keep blinking to survive!', 
               textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildStatRow('Score', '${_viewModel.carState.score}'),
                const Divider(color: Colors.white24),
                _buildStatRow('Bonuses', '${_viewModel.carState.bonusesCollected}'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _viewModel.resetGame(),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('PLAY AGAIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isWon ? Colors.green : Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }
}