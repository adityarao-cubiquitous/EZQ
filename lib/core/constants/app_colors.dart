import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const cubiquitousMint = Color(0xFFCDFFD8);
  static const cubiquitousAqua = Color(0xFFB0DCEB);
  static const cubiquitousSky = Color(0xFF94B9FF);
  static const tracuraPurple = Color(0xFF8461F4);
  static const tracuraCyan = Color(0xFF81D8E5);

  static const primaryTeal = Color(0xFF18AFC5);
  static const secondaryCyan = tracuraCyan;
  static const accentPurple = tracuraPurple;
  static const navyText = Color(0xFF102331);
  static const mutedText = Color(0xFF607D8B);
  static const background = Color(0xFFFFFFFF);
  static const softSurface = Color(0xFFEAF8FA);
  static const softerSurface = Color(0xFFF6FAFF);
  static const line = Color(0xFFB0DCEB);
  static const errorRed = Color(0xFFE05C5C);
  static const successGreen = Color(0xFF24A148);
  static const warningOrange = Color(0xFFF59E0B);
  static const deepTeal = Color(0xFF006B7A);
  static const inkBlue = Color(0xFF102331);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryTeal, deepTeal],
  );

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tracuraPurple, tracuraCyan],
  );

  static const progressGradient = LinearGradient(
    colors: [cubiquitousMint, secondaryCyan, cubiquitousSky],
  );
}
