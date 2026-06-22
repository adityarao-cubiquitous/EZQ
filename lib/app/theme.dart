import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class EzqTheme {
  const EzqTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryTeal,
        primary: AppColors.primaryTeal,
        secondary: AppColors.secondaryCyan,
        tertiary: AppColors.accentPurple,
        error: AppColors.errorRed,
        surface: AppColors.background,
      ),
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.softerSurface,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.navyText,
        displayColor: AppColors.navyText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.primaryTeal,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
