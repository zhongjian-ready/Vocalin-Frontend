import 'package:flutter/material.dart';
import 'dart:math' as math;

class VocalinLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const VocalinLogo({
    super.key,
    this.size = 48,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    // Brand colors extracted from the image
    const blueColor = Color(0xFF2B5D88);
    const orangeColor = Color(0xFFE89D5E);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _NestLogoPainter(blueColor: blueColor, orangeColor: orangeColor),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vocalin',
                style: TextStyle(
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.bold,
                  color: blueColor,
                  height: 1.0,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '窝聚',
                style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w500,
                  color: orangeColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NestLogoPainter extends CustomPainter {
  final Color blueColor;
  final Color orangeColor;

  _NestLogoPainter({required this.blueColor, required this.orangeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.06;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 1. Outer Circle (Blue)
    paint.color = blueColor;
    canvas.drawCircle(center, radius * 0.9, paint);

    // 2. The "Nest" Structure
    // We simulate the interwoven twigs using arcs
    
    // Bottom Blue Nest part
    paint.color = blueColor;
    final nestRect = Rect.fromCircle(center: center, radius: radius * 0.65);
    canvas.drawArc(nestRect, 0.1 * math.pi, 0.8 * math.pi, false, paint);
    
    // Inner Blue arc
    canvas.drawArc(
      Rect.fromCircle(center: center.translate(0, size.height * 0.1), radius: radius * 0.5), 
      0.2 * math.pi, 0.6 * math.pi, false, paint
    );

    // Top Orange Nest part (The "roof" or upper twigs)
    paint.color = orangeColor;
    canvas.drawArc(nestRect, 1.1 * math.pi, 0.8 * math.pi, false, paint);
    
    // Decorative crossing lines (Twigs)
    paint.strokeWidth = strokeWidth * 0.7;
    
    // Orange twig
    canvas.drawLine(
      center + Offset(-radius * 0.4, -radius * 0.15),
      center + Offset(radius * 0.4, -radius * 0.05),
      paint,
    );

    // Blue twig
    paint.color = blueColor;
    canvas.drawLine(
      center + Offset(-radius * 0.3, radius * 0.25),
      center + Offset(radius * 0.3, radius * 0.25),
      paint,
    );

    // 3. The "V" in the center
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'V',
        style: TextStyle(
          color: blueColor,
          fontSize: size.width * 0.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'Arial', // Use a standard sans-serif
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas, 
      center - Offset(textPainter.width / 2, textPainter.height / 2 * 0.9), // Slightly adjust vertical center
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
