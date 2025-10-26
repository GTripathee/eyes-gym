import 'package:eyesgym/models/face_detection_state.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class RoadPainter extends CustomPainter {
  final CarState carState;
  final List<BonusItem> bonusItems;

  RoadPainter({required this.carState, required this.bonusItems});

  @override
  void paint(Canvas canvas, Size size) {
    final roadWidth = size.width * 0.35; // Narrower road (was 0.6)
    final roadLeft = (size.width - roadWidth) / 2;
    
    // Draw grass background
    final grassPaint = Paint()..color = Colors.green[700]!;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), grassPaint);
    
    // Draw road
    final roadPaint = Paint()..color = Colors.grey[700]!;
    canvas.drawRect(
      Rect.fromLTWH(roadLeft, 0, roadWidth, size.height),
      roadPaint,
    );
    
    // Draw road edges
    final edgePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8;
    
    canvas.drawLine(
      Offset(roadLeft, 0),
      Offset(roadLeft, size.height),
      edgePaint,
    );
    canvas.drawLine(
      Offset(roadLeft + roadWidth, 0),
      Offset(roadLeft + roadWidth, size.height),
      edgePaint,
    );
    
    // Draw START marker at top
    _drawTextMarker(canvas, size, 'START', 50, Colors.green);
    
    // Draw FINISH marker at bottom
    _drawTextMarker(canvas, size, 'FINISH', size.height - 80, Colors.red);
    
    // Draw lane markings (dashed center line)
    final lanePaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    
    const dashHeight = 30.0;
    const dashSpace = 20.0;
    double startY = 0;
    
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        lanePaint,
      );
      startY += dashHeight + dashSpace;
    }
    
    // Draw progress markers (0%, 25%, 50%, 75%)
    final markerPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2;
    
    for (double progress in [0.25, 0.5, 0.75]) {
      final y = size.height * (1 - progress);
      canvas.drawLine(
        Offset(roadLeft, y),
        Offset(roadLeft + roadWidth, y),
        markerPaint,
      );
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(progress * 100).toInt()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(roadLeft - 40, y - 6));
    }
    
    // Draw bonus items
    for (var bonus in bonusItems) {
      if (!bonus.collected) {
        _drawBonus(canvas, size, bonus, roadWidth, roadLeft);
      }
    }
    
    // Draw car at its current progress position
    _drawCar(canvas, size, carState, roadWidth, roadLeft);
  }
  
  void _drawTextMarker(Canvas canvas, Size size, String text, double y, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final x = (size.width - textPainter.width) / 2;
    
    // Draw background
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 10, y - 5, textPainter.width + 20, textPainter.height + 10),
        const Radius.circular(8),
      ),
      bgPaint,
    );
    
    textPainter.paint(canvas, Offset(x, y));
  }
  
  void _drawBonus(Canvas canvas, Size size, BonusItem bonus, double roadWidth, double roadLeft) {
    // Calculate position on screen (inverted - start at bottom, end at top)
    final y = size.height * (1 - bonus.position);
    final x = size.width / 2 + (bonus.lanePosition * roadWidth / 2);
    
    // Draw bonus as a star or coin
    final bonusPaint = Paint()
      ..color = bonus.points > 10 ? Colors.amber : Colors.yellow
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = Colors.orange[900]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Draw star shape
    final path = Path();
    final radius = 15.0;
    final innerRadius = radius * 0.5;
    
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2;
      final nextAngle = ((i + 0.5) * 2 * math.pi / 5) - math.pi / 2;
      
      if (i == 0) {
        path.moveTo(
          x + radius * math.cos(angle),
          y + radius * math.sin(angle),
        );
      } else {
        path.lineTo(
          x + radius * math.cos(angle),
          y + radius * math.sin(angle),
        );
      }
      
      path.lineTo(
        x + innerRadius * math.cos(nextAngle),
        y + innerRadius * math.sin(nextAngle),
      );
    }
    path.close();
    
    canvas.drawPath(path, bonusPaint);
    canvas.drawPath(path, borderPaint);
    
    // Draw points value
    if (bonus.points > 10) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '+${bonus.points}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }
  
  void _drawCar(Canvas canvas, Size size, CarState carState, double roadWidth, double roadLeft) {
    // Car position based on progress (inverted - starts at bottom, moves to top)
    final carY = size.height * (1 - carState.progress);
    // Car stays centered horizontally
    final carX = size.width / 2;
    final carWidth = roadWidth * 0.18; // Smaller car (was 0.25)
    final carHeight = carWidth * 1.8;
    
    // Draw car body
    final carPaint = Paint()..color = Colors.blue[700]!;
    
    final carRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(carX, carY),
        width: carWidth,
        height: carHeight,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(carRect, carPaint);
    
    // Draw car outline
    final outlinePaint = Paint()
      ..color = Colors.blue[900]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(carRect, outlinePaint);
    
    // Draw windshield
    final windowPaint = Paint()..color = Colors.lightBlue[200]!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(carX, carY - carHeight * 0.15),
          width: carWidth * 0.7,
          height: carHeight * 0.35,
        ),
        const Radius.circular(8),
      ),
      windowPaint,
    );
    
    // Draw wheels
    final wheelPaint = Paint()..color = Colors.black;
    final wheelRadius = carWidth * 0.15;
    
    // Left wheels
    canvas.drawCircle(
      Offset(carX - carWidth * 0.3, carY - carHeight * 0.3),
      wheelRadius,
      wheelPaint,
    );
    canvas.drawCircle(
      Offset(carX - carWidth * 0.3, carY + carHeight * 0.3),
      wheelRadius,
      wheelPaint,
    );
    
    // Right wheels
    canvas.drawCircle(
      Offset(carX + carWidth * 0.3, carY - carHeight * 0.3),
      wheelRadius,
      wheelPaint,
    );
    canvas.drawCircle(
      Offset(carX + carWidth * 0.3, carY + carHeight * 0.3),
      wheelRadius,
      wheelPaint,
    );
  }

  @override
  bool shouldRepaint(RoadPainter oldDelegate) => true;
}