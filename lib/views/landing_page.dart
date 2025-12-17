import 'package:camera/camera.dart';
import 'package:eyesgym/views/dashboard_screen.dart';
import 'package:eyesgym/views/game_screen.dart';
import 'package:eyesgym/views/focus_session_screen.dart';
import 'package:flutter/material.dart';

class LandingPage extends StatelessWidget {
  final CameraDescription camera;

  const LandingPage({Key? key, required this.camera}) : super(key: key);

  void _navigateToDashboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DashboardScreen(camera: camera)),
    );
  }

  void _navigateToGame(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameScreen(camera: camera)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // LOGO / ICON AREA
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.visibility,
                    size: 80,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // TITLE
              const Text(
                "Eye Gym",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Strengthen your eyes.\nImprove your focus.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              
              const Spacer(),
              
              _buildMenuButton(
                context,
                title: "START RACE",
                subtitle: "Gamified Blink Training",
                icon: Icons.sports_esports,
                color: Colors.green,
                onTap: () => _navigateToGame(context),
              ),
              
              const SizedBox(height: 16),
              
              // 2. ZEN FOCUS (NEW)
              _buildMenuButton(
                context,
                title: "ZEN FOCUS",
                subtitle: "Audio-Guided Therapy",
                icon: Icons.headphones,
                color: Colors.purpleAccent,
                onTap: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FocusSessionScreen(camera: camera)),
                    );
                },
              ),
              
              const SizedBox(height: 16),
              
              // 3. DASHBOARD
              _buildMenuButton(
                context,
                title: "MY DASHBOARD",
                subtitle: "View progress & streaks",
                icon: Icons.bar_chart_rounded,
                color: Colors.blueAccent,
                onTap: () => _navigateToDashboard(context),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.3), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}