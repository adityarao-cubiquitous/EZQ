import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/restaurant_logo_asset.dart';

class AdminBranchIdentityPill extends StatelessWidget {
  const AdminBranchIdentityPill({
    super.key,
    required this.restaurantName,
    required this.restaurantSlug,
    this.compact = false,
  });

  final String restaurantName;
  final String? restaurantSlug;
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
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(11)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                restaurantLogoAsset(restaurantSlug),
                width: logoSize,
                height: logoSize,
                fit: BoxFit.contain,
              ),
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
      ),
    );
  }
}
