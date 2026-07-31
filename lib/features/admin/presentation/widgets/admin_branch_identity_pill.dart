import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/restaurant_logo.dart';

class AdminBranchIdentityPill extends StatelessWidget {
  const AdminBranchIdentityPill({
    super.key,
    required this.restaurantBranchId,
    required this.restaurantName,
    this.compact = false,
  });

  final String restaurantBranchId;
  final String restaurantName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 30.0 : 36.0;
    final textStyle = TextStyle(
      color: Colors.white,
      fontFamily: 'Poppins',
      fontSize: compact ? 16 : 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );

    return Container(
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 560),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A6A40D7),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 7,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RestaurantLogo(
            restaurantBranchId: restaurantBranchId,
            size: logoSize,
            shape: RestaurantLogoShape.circle,
            showShadow: false,
          ),
          SizedBox(width: compact ? 8 : 12),
          Flexible(
            child: Text(
              restaurantName,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}
