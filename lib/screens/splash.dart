import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Splash: original ledger-mark artwork (CustomPainter), tagline, footer.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [HBColors.gradientTop, HBColors.gradientBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                // Original logo mark: open ledger book drawn in code.
                CustomPaint(
                  size: const Size(120, 120),
                  painter: _LedgerMarkPainter(),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Hisab Business',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Every rupee, accounted.',
                  style: TextStyle(
                      fontSize: 16, color: Colors.white70),
                ),
                const Spacer(flex: 3),
                const Text(
                  'Crafted in Pakistan',
                  style: TextStyle(
                      fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Original artwork: an open ledger book (white strokes on brand orange).
class _LedgerMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Left page
    final left = Path()
      ..moveTo(cx, h * 0.22)
      ..quadraticBezierTo(w * 0.28, h * 0.12, w * 0.10, h * 0.24)
      ..lineTo(w * 0.10, h * 0.78)
      ..quadraticBezierTo(w * 0.28, h * 0.66, cx, h * 0.76)
      ..close();
    // Right page
    final right = Path()
      ..moveTo(cx, h * 0.22)
      ..quadraticBezierTo(w * 0.72, h * 0.12, w * 0.90, h * 0.24)
      ..lineTo(w * 0.90, h * 0.78)
      ..quadraticBezierTo(w * 0.72, h * 0.66, cx, h * 0.76)
      ..close();
    canvas.drawPath(left, paint..style = PaintingStyle.fill);
    canvas.drawPath(right, paint..style = PaintingStyle.fill);

    // Spine + ledger lines
    final line = Paint()
      ..color = HBColors.primaryDeep
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(cx, h * 0.22), Offset(cx, h * 0.76), line);
    for (var i = 0; i < 3; i++) {
      final y = h * (0.38 + i * 0.11);
      canvas.drawLine(
          Offset(w * 0.18, y), Offset(cx - w * 0.06, y - h * 0.02), line);
      canvas.drawLine(
          Offset(cx + w * 0.06, y - h * 0.02), Offset(w * 0.82, y), line);
    }

    // Rupee arc above the book (brand sun)
    final arc = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, h * 0.30), radius: w * 0.06),
        -math.pi * 0.85,
        math.pi * 0.7,
        false,
        arc);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
