import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class AdminBranchIdentityPill extends StatelessWidget {
  const AdminBranchIdentityPill({
    super.key,
    required this.restaurantName,
    this.compact = false,
  });

  final String restaurantName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 30.0 : 36.0;
    final textStyle = TextStyle(
      color: Colors.white,
      fontFamily: 'Poppins',
      fontSize: compact ? 16 : 18,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );

    return Container(
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 560),
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white,
              Color(0xFFF7FDFF),
              Color(0xFFF6FAFF),
              Color(0xFFFFF7FF),
            ],
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/brand/restaurant_logo.png',
                width: logoSize,
                height: logoSize,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: compact ? 8 : 12),
            Flexible(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.deepTeal,
                      AppColors.primaryTeal,
                      Color(0xFF176DE8),
                      Color(0xFF7A2FD8),
                    ],
                  ).createShader(bounds);
                },
                child: Text(
                  restaurantName,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
