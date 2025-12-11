import 'package:eyesgym/models/face_detection_state.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class RoadPainter extends CustomPainter {
  final CarState carState;
  final List<BonusItem> bonusItems;
  final List<ObstacleItem> obstacles;

  RoadPainter({
    required this.carState,
    required this.bonusItems,
    this.obstacles = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Setup Road Dimensions
    final roadWidth = size.width * 0.5;
    final roadLeft = (size.width - roadWidth) / 2;
    final roadRight = roadLeft + roadWidth;
    final centerX = size.width / 2;

    // 2. Draw Backgrounds
    // Grass
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.green[800]!,
    );
    // Road
    canvas.drawRect(
      Rect.fromLTWH(roadLeft, 0, roadWidth, size.height),
      Paint()..color = Colors.grey[800]!,
    );
    // Road Borders
    final borderPaint = Paint()..color = Colors.white..strokeWidth = 4;
    canvas.drawLine(Offset(roadLeft, 0), Offset(roadLeft, size.height), borderPaint);
    canvas.drawLine(Offset(roadRight, 0), Offset(roadRight, size.height), borderPaint);

    // 3. Draw Moving Lane Markings
    // We animate the offset based on car progress to simulate speed
    double laneOffset = (carState.progress * 3000) % 80;
    _drawLanes(canvas, centerX, size.height, laneOffset);

    // 4. Calculate Car Position (Crucial Fix)
    // Car stays fixed at 80% down the screen (Chase View)
    final carY = size.height * 0.8;
    // Map xPosition (-1.0 to 1.0) to screen coordinates
    // We limit movement to inside the road boundaries (0.4 factor keeps it safe)
    final carX = centerX + (carState.xPosition * roadWidth * 0.4);
    final carCenter = Offset(carX, carY);

    // 5. Draw Items (Relative to Car Progress)
    // Since car is fixed at bottom, items must scroll down based on progress diff
    _drawItems(canvas, size, roadWidth, roadLeft, carState.progress);

    // 6. Draw Charging Effect (Attached to Car Center)
    if (carState.isCharging) {
      _drawChargeEffect(canvas, carCenter, carState.chargeLevel);
    }

    // 7. Draw Car (At Calculated Center)
    _drawCar(canvas, carCenter, carState);
    
    // 8. Draw Progress HUD
    _drawProgress(canvas, size, carState.progress);
  }

  void _drawLanes(Canvas canvas, double centerX, double height, double offset) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 4;
      
    // Draw dashed lines loop
    for (double i = -100; i < height + 100; i += 80) {
      canvas.drawLine(
        Offset(centerX, i + offset),
        Offset(centerX, i + 40 + offset),
        paint,
      );
    }
  }

  void _drawItems(Canvas canvas, Size size, double roadWidth, double roadLeft, double carProgress) {
    // Visible range: We want to see items that are slightly ahead of the car
    // In this "Chase View", the car is physically at 0.8 screen height, 
    // but logically at 'carProgress' on the track.
    
    final viewHeight = size.height;
    
    // Helper to draw a single list of items
    void drawList(List<RoadItem> items, bool isObstacle) {
      for (var item in items) {
        if (item is BonusItem && item.collected) continue; // Skip collected
        if (item is ObstacleItem && item.hit) continue; // Skip hit obstacles (optional)

        // Calculate Relative Position
        // distanceAhead = how far the item is ahead of the car in track %
        final distanceAhead = item.position - carProgress;
        
        // If item is too far behind or too far ahead, skip
        if (distanceAhead < -0.1 || distanceAhead > 0.5) continue;

        // Map distance to screen Y
        // If distance is 0 (at car), Y should be carY (0.8 * height)
        // If distance is positive (ahead), Y should be smaller (higher up)
        // Scale factor: 2.0 means the screen shows 50% of the track at once
        final screenY = (size.height * 0.8) - (distanceAhead * size.height * 2.5);
        
        final centerX = roadLeft + (roadWidth / 2);
        final screenX = centerX + (item.lanePosition * roadWidth * 0.4);

        if (isObstacle) {
          _drawObstacle(canvas, Offset(screenX, screenY));
        } else {
          _drawBonus(canvas, Offset(screenX, screenY));
        }
      }
    }

    drawList(bonusItems, false);
    drawList(obstacles, true);
  }

  void _drawBonus(Canvas canvas, Offset center) {
    // Outer Glow
    canvas.drawCircle(center, 15, Paint()..color = Colors.amber.withOpacity(0.5));
    // Star/Coin
    canvas.drawCircle(center, 10, Paint()..color = Colors.yellow);
    canvas.drawCircle(center, 8, Paint()..color = Colors.orangeAccent);
    // Sparkle
    canvas.drawCircle(center + const Offset(-3, -3), 3, Paint()..color = Colors.white);
  }

  void _drawObstacle(Canvas canvas, Offset center) {
    // Rock Body
    canvas.drawCircle(center, 18, Paint()..color = Colors.brown[800]!);
    canvas.drawCircle(center + const Offset(-4, -4), 14, Paint()..color = Colors.brown[600]!);
    // Highlight
    canvas.drawCircle(center + const Offset(-6, -6), 4, Paint()..color = Colors.brown[400]!);
  }

  void _drawChargeEffect(Canvas canvas, Offset center, double level) {
    // Pulsing Aura
    final radius = 30.0 + (level * 25.0);
    final opacity = (0.2 + (level * 0.5)).clamp(0.0, 1.0);
    
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(opacity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawCircle(center, radius, paint);
    
    // Core Energy
    canvas.drawCircle(
      center, 
      25, 
      Paint()
        ..color = Colors.white.withOpacity(level * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
    );
  }

  void _drawCar(Canvas canvas, Offset center, CarState car) {
    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: center + const Offset(0, 25), width: 40, height: 15),
      Paint()..color = Colors.black.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Body Color
    final color = car.isCrashed ? Colors.red : (car.isCharging ? Colors.blueAccent : Colors.blue);

    // Car Shape (Rounded Rect)
    final carRect = Rect.fromCenter(center: center, width: 40, height: 60);
    final rrect = RRect.fromRectAndRadius(carRect, const Radius.circular(12));
    
    canvas.drawRRect(rrect, Paint()..color = color);
    
    // Windshield (Back)
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 14, center.dy + 5, 28, 15),
      Paint()..color = Colors.lightBlue[100]!,
    );
    
    // Roof
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 16, center.dy - 10, 32, 15),
      Paint()..color = color.withOpacity(0.8), // Slightly darker
    );

    // Wheels
    final wheelPaint = Paint()..color = Colors.black;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(center.dx - 24, center.dy - 20, 6, 14), const Radius.circular(3)), wheelPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(center.dx + 18, center.dy - 20, 6, 14), const Radius.circular(3)), wheelPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(center.dx - 24, center.dy + 15, 6, 14), const Radius.circular(3)), wheelPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(center.dx + 18, center.dy + 15, 6, 14), const Radius.circular(3)), wheelPaint);
  }
  
  void _drawProgress(Canvas canvas, Size size, double progress) {
    // Simple bar at the top
    final barWidth = size.width * 0.8;
    final barHeight = 10.0;
    final barLeft = (size.width - barWidth) / 2;
    final barTop = 50.0;
    
    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barLeft, barTop, barWidth, barHeight), const Radius.circular(5)),
      Paint()..color = Colors.black54,
    );
    
    // Fill
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barLeft, barTop, barWidth * progress, barHeight), const Radius.circular(5)),
      Paint()..color = Colors.greenAccent,
    );
    
    // Flag icon at end
    const iconSize = 20.0;
    final textPainter = TextPainter(
      text: const TextSpan(text: "🏁", style: TextStyle(fontSize: iconSize)),
      textDirection: TextDirection.ltr
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(barLeft + barWidth - (iconSize/2), barTop - 5));
  }

  @override
  bool shouldRepaint(RoadPainter oldDelegate) => true;
}