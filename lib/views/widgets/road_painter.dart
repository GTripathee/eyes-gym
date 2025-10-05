import 'package:eyesgym/models/face_detection_state.dart';
import 'package:flutter/material.dart';

class RoadPainter extends CustomPainter {
  final CarState carState;
  final List<Obstacle> obstacles;

  RoadPainter({required this.carState, required this.obstacles});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw road
    final roadPaint = Paint()..color = Colors.grey[700]!;
    final roadWidth = size.width * 0.6;
    final roadLeft = (size.width - roadWidth) / 2;
    
    canvas.drawRect(
      Rect.fromLTWH(roadLeft, 0, roadWidth, size.height),
      roadPaint,
    );
    
    // Draw lane markings
    final lanePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 20),
        lanePaint,
      );
    }
    
    // Draw obstacles
    final obstaclePaint = Paint()..color = Colors.red;
    for (var obstacle in obstacles) {
      final x = size.width / 2 + (obstacle.xPosition * roadWidth / 2);
      final y = obstacle.yPosition * size.height;
      final width = obstacle.width * roadWidth;
      
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, y),
          width: width,
          height: width * 1.5,
        ),
        obstaclePaint,
      );
    }
    
    // Draw car
    final carPaint = Paint()..color = Colors.blue;
    final carX = size.width / 2 + (carState.xPosition * roadWidth / 2);
    final carY = size.height * 0.8;
    final carWidth = roadWidth * 0.1;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(carX, carY),
          width: carWidth,
          height: carWidth * 1.8,
        ),
        const Radius.circular(8),
      ),
      carPaint,
    );
    
    // Draw car windows
    final windowPaint = Paint()..color = Colors.lightBlue[200]!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(carX, carY - carWidth * 0.3),
          width: carWidth * 0.7,
          height: carWidth * 0.6,
        ),
        const Radius.circular(4),
      ),
      windowPaint,
    );
  }

  @override
  bool shouldRepaint(RoadPainter oldDelegate) => true;
}