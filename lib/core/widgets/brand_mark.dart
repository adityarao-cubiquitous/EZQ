import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _EzqMarkPainter()),
    );
  }
}

class _EzqMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final cornerRadius = size.width * 0.26;

    final backgroundPath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)));
    canvas.drawShadow(
      backgroundPath,
      AppColors.deepTeal.withValues(alpha: 0.18),
      size.width * 0.08,
      true,
    );

    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFEAF9FD)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)),
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..color = const Color(0x997FD9EB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(size.width * 0.025),
        Radius.circular(cornerRadius),
      ),
      borderPaint,
    );

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final qPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.deepTeal;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.23),
      -math.pi * 0.18,
      math.pi * 1.82,
      false,
      qPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.58, size.height * 0.59),
      Offset(size.width * 0.72, size.height * 0.72),
      qPaint,
    );

    final dotPaint = Paint()..color = AppColors.primaryTeal;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.055,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
