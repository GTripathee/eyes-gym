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
      return Center(child: Text('Error: ${_viewModel.errorMessage}'));
    }
    
    if (!_viewModel.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Stack(
      children: [
        _buildGameView(),
        // Camera Preview
        Positioned(
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
        ),
        _buildGameOverlay(),
      ],
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
  
  Widget _buildGameOverlay() {
    return SafeArea(
      child: Stack(
        children: [
          // 1. Status Bar (Only visible when playing)
          if (_viewModel.isGameRunning)
            Positioned(top: 0, left: 0, right: 0, child: _buildStatusBar()),

          // 2. Exit Button (During Game Only)
          if (_viewModel.isGameRunning)
            Positioned(
              top: 10,
              left: 10,
              child: _buildInGameExitButton(),
            ),

          // 3. Center Screens (Start / Game Over)
          Center(
             child: SingleChildScrollView(
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
          ),
        ],
      ),
    );
  }
  
  Widget _buildInGameExitButton() {
    return IconButton(
      onPressed: () => _showExitDialog(),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), shape: BoxShape.circle),
        child: const Icon(Icons.close, color: Colors.white, size: 24),
      ),
    );
  }

  // --- UPDATED DIALOG LOGIC ---
  Future<void> _showExitDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          title: const Text('End Session?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Progress from this run will be discarded.',
            style: TextStyle(color: Colors.white70)
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Quit to Menu', style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                Navigator.of(context).pop(); // Close Dialog
                // Instead of popping the screen, we just reset the game
                _viewModel.resetGame(); 
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBar() {
    final progress = _viewModel.carState.progress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text('⭐ ${_viewModel.carState.score}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
             const SizedBox(width: 15),
             Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // --- START SCREEN ---
  Widget _buildStartScreen() {
    final hasFace = _viewModel.detectionState.hasFaceDetected;
    
    return Container(
      width: 320,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Dashboard Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(), // Go back to Dashboard
                tooltip: "Back to Dashboard",
              ),
              const Text(
                'Eye Race', 
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)
              ),
              const SizedBox(width: 48), // Spacer to center title
            ],
          ),
          
          const SizedBox(height: 20),
          const Center(child: Text('Select Difficulty:', style: TextStyle(color: Colors.white70))),
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('START RACE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          
          if (!hasFace)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Text('⚠️ Face not detected', style: TextStyle(color: Colors.orange[300], fontWeight: FontWeight.bold)),
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
          Text(isWon ? 'VICTORY!' : 'GAME OVER', 
               style: TextStyle(color: isWon ? Colors.green : Colors.red, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          _buildStatRow('Score', '${_viewModel.carState.score}'),
          const SizedBox(height: 8),
          _buildStatRow('Bonuses', '${_viewModel.carState.bonusesCollected}'),
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               // THIS BUTTON RETURNS TO MENU (RESET), NOT DASHBOARD
               OutlinedButton(
                   onPressed: () => _viewModel.resetGame(), 
                   style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                   child: const Icon(Icons.menu, color: Colors.white),
               ),
               const SizedBox(width: 16),
               ElevatedButton(
                   onPressed: () => _viewModel.startGame(), // Instant Retry
                   style: ElevatedButton.styleFrom(backgroundColor: isWon ? Colors.green : Colors.red),
                   child: const Text('RETRY', style: TextStyle(color: Colors.white)),
               ),
            ],
          )
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