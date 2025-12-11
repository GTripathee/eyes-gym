import 'package:eyesgym/models/face_detection_state.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class RoadPainter extends CustomPainter {
  final CarState carState;
  final List<BonusItem> bonusItems;

  RoadPainter({required this.carState, required this.bonusItems});

  @override
  void paint(Canvas canvas, Size size) {
    final roadWidth = size.width * 0.4; 
    final roadLeft = (size.width - roadWidth) / 2;
    
    // 1. Draw Grass
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.green[800]!);
    
    // 2. Draw Road
    canvas.drawRect(Rect.fromLTWH(roadLeft, 0, roadWidth, size.height), Paint()..color = Colors.grey[800]!);
    
    // 3. Draw Lane Markings (Moving effect)
    // We use car progress to offset lines to create illusion of speed
    double offset = (carState.progress * 1000) % 50; 
    _drawLaneMarkings(canvas, size, roadWidth, offset);

    // 4. Draw Bonuses
    for (var bonus in bonusItems) {
      if (!bonus.collected) {
        // Only draw if visible on screen
        double screenY = _getScreenY(size, bonus.position, carState.progress);
        if (screenY > -50 && screenY < size.height + 50) {
             _drawBonus(canvas, size, screenY, roadWidth);
        }
      }
    }
    
    // 5. Draw Car
    _drawCar(canvas, size, carState, roadWidth);
    
    // 6. Draw Charging Effect (Power Blink)
    if (carState.isCharging) {
        _drawChargeEffect(canvas, size, carState.chargeLevel);
    }
  }
  
  double _getScreenY(Size size, double objectProgress, double carProgress) {
      // Simple perspective projection: 
      // Objects move down as car moves up (progress increases)
      // We keep the car fixed at 80% down the screen usually, 
      // but here we are mapping 0-1 progress to full height.
      // Let's map progress relative to road length.
      return size.height * (1 - (objectProgress));
  }
  
  void _drawLaneMarkings(Canvas canvas, Size size, double roadWidth, double offset) {
      final paint = Paint()..color = Colors.white.withOpacity(0.5)..strokeWidth = 4;
      double centerX = size.width / 2;
      for (double i = -50; i < size.height + 50; i += 50) {
          canvas.drawLine(
              Offset(centerX, i + offset), 
              Offset(centerX, i + 30 + offset), 
              paint
          );
      }
  }
  
  void _drawBonus(Canvas canvas, Size size, double y, double roadWidth) {
    final x = size.width / 2;
    canvas.drawCircle(Offset(x, y), 10, Paint()..color = Colors.amber);
    canvas.drawCircle(Offset(x, y), 12, Paint()..color = Colors.orange..style=PaintingStyle.stroke..strokeWidth=2);
  }
  
  void _drawCar(Canvas canvas, Size size, CarState carState, double roadWidth) {
    // Car is fixed vertically at 80% height for a "chase cam" feel, 
    // OR moves up as per your original logic. 
    // Your original logic moved the car up. Let's stick to that for simplicity.
    final carY = size.height * (1 - carState.progress);
    final carX = size.width / 2;
    
    // Draw Car Body
    canvas.drawRect(
        Rect.fromCenter(center: Offset(carX, carY), width: 40, height: 60), 
        Paint()..color = Colors.blue
    );
  }
  
  void _drawChargeEffect(Canvas canvas, Size size, double level) {
      final center = Offset(size.width / 2, size.height * (1 - carState.progress));
      
      // Draw growing circle behind car
      final radius = 40.0 + (level * 20.0);
      final opacity = 0.3 + (level * 0.4);
      
      final paint = Paint()
        ..color = Colors.cyanAccent.withOpacity(opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        
      canvas.drawCircle(center, radius, paint);
      
      // Draw text "POWER CHARGE" if level is high
      if (level > 0.8) {
          final textPainter = TextPainter(
            text: const TextSpan(
                text: "NITRO READY!",
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)
            ),
            textDirection: TextDirection.ltr
          );
          textPainter.layout();
          textPainter.paint(canvas, center + const Offset(-40, -80));
      }
  }

  @override
  bool shouldRepaint(RoadPainter oldDelegate) => true;
}