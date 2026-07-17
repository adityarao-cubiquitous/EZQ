import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    final padding = (size * 0.08).clamp(2.0, 8.0);
    final radius = (size * 0.22).clamp(6.0, 18.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFF061B3A),
        padding: EdgeInsets.all(padding),
        alignment: Alignment.center,
        child: Image.asset(
          'assets/brand/ezq_logo.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
