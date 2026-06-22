import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const primaryTeal = Color(0xFF12A9DC);
  static const secondaryCyan = Color(0xFF7FD9EB);
  static const accentPurple = Color(0xFF6A40D7);
  static const navyText = Color(0xFF0D1F2D);
  static const mutedText = Color(0xFF607D8B);
  static const background = Color(0xFFFFFFFF);
  static const softSurface = Color(0xFFE8F6FC);
  static const softerSurface = Color(0xFFF7F9FF);
  static const line = Color(0xFFD8EAFE);
  static const errorRed = Color(0xFFE05C5C);
  static const successGreen = Color(0xFF24A148);
  static const warningOrange = Color(0xFFF59E0B);
  static const deepTeal = Color(0xFF006687);
  static const inkBlue = Color(0xFF00394D);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryTeal, deepTeal],
  );

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryTeal, accentPurple],
  );

  static const progressGradient = LinearGradient(
    colors: [secondaryCyan, primaryTeal],
  );
}
