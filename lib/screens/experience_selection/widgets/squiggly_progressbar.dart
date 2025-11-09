import 'package:flutter/material.dart';
import 'dart:ui'; // Needed for PathMetric

class SquigglyProgressBar extends StatelessWidget {
  final int step; // 0 to 7 (how many waves are active)

  const SquigglyProgressBar({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    // Set a fixed size for the custom painter
    return CustomPaint(
      size: const Size(200, 20), // Adjust width and height as needed
      painter: _SquigglyPainter(step),
    );
  }
}

class _SquigglyPainter extends CustomPainter {
  final int step;
  static const int segmentCount = 7; // Total number of wave segments

  _SquigglyPainter(this.step);

  @override
  void paint(Canvas canvas, Size size) {
    final paintActive = Paint()
      // This is the purple-blue color from your design
      ..color = const Color(0xFF8B5CF6) 
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final paintInactive = Paint()
      // This is the darker grey from your design
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final segmentWidth = size.width / segmentCount;
    final midY = size.height / 2; // Middle of the canvas height

    // Create one continuous squiggly wave path
    path.moveTo(0, midY); // Start at the left middle
    for (int i = 0; i < segmentCount; i++) {
      // Control point for the curve
      final cpX = (i * segmentWidth) + (segmentWidth * 0.5);
      // Flipped logic: i.isEven goes UP (negative), i.isOdd goes DOWN (positive)
      final cpY = midY + (i.isEven ? -6 : 6); 

      final endX = (i + 1) * segmentWidth;

      // Use quadraticBezierTo for the simple arch
      path.quadraticBezierTo(cpX, cpY, endX, midY);
    }

    // Use PathMetric to get the exact length and extract sub-paths
    final PathMetric metric = path.computeMetrics().first;

    // Calculate the length of the active part based on 'step'
    final double activeLength = metric.length * (step / segmentCount);

    // Extract the active and inactive parts of the path
    final Path pathActive = metric.extractPath(0, activeLength);
    final Path pathInactive = metric.extractPath(activeLength, metric.length);

    // Draw the active and inactive paths
    canvas.drawPath(pathInactive, paintInactive); // Draw inactive first
    canvas.drawPath(pathActive, paintActive);     // Draw active over it
  }

  @override
  bool shouldRepaint(_SquigglyPainter oldDelegate) {
    return oldDelegate.step != step;
  }
}