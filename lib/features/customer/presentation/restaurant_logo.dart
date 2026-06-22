import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class RestaurantLogo extends StatelessWidget {
  const RestaurantLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4DC), Color(0xFFE8F6FC)],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A12A9DC),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.16,
            right: size * 0.14,
            child: Icon(
              Icons.local_fire_department,
              color: AppColors.warningOrange.withValues(alpha: 0.8),
              size: size * 0.23,
            ),
          ),
          Icon(Icons.restaurant, color: AppColors.deepTeal, size: size * 0.34),
          Positioned(
            bottom: size * 0.13,
            child: Text(
              'SH',
              style: TextStyle(
                color: AppColors.navyText,
                fontSize: size * 0.22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
