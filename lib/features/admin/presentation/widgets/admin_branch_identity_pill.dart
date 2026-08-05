import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/restaurant_logo.dart';
import '../../../customer/domain/restaurant_branch_identity.dart';

class AdminBranchIdentityPill extends StatelessWidget {
  const AdminBranchIdentityPill({
    super.key,
    required this.identity,
    this.compact = false,
  }) : loadingRestaurantBranchId = null;

  const AdminBranchIdentityPill.loading({
    super.key,
    required String restaurantBranchId,
    this.compact = false,
  }) : identity = null,
       loadingRestaurantBranchId = restaurantBranchId;

  final RestaurantBranchIdentity? identity;
  final String? loadingRestaurantBranchId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final loadedIdentity = identity;
    final restaurantBranchId =
        loadedIdentity?.restaurantBranchId ?? loadingRestaurantBranchId!;
    final logoSize = compact ? 30.0 : 36.0;
    final restaurantTextStyle = TextStyle(
      color: Colors.white,
      fontFamily: 'Poppins',
      fontSize: compact ? 16 : 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
    final branchTextStyle = restaurantTextStyle.copyWith(
      color: Colors.white.withValues(alpha: 0.82),
      fontSize: compact ? 11 : 12,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
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
            child: loadedIdentity == null
                ? _AdminBranchIdentityLoadingText(compact: compact)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loadedIdentity.restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: restaurantTextStyle,
                      ),
                      Text(
                        loadedIdentity.branchName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: branchTextStyle,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdminBranchIdentityLoadingText extends StatelessWidget {
  const _AdminBranchIdentityLoadingText({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading restaurant and branch',
      child: SizedBox(
        width: compact ? 132 : 190,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LoadingLine(width: compact ? 112 : 160, height: compact ? 12 : 14),
            const SizedBox(height: 4),
            _LoadingLine(width: compact ? 76 : 104, height: 8),
          ],
        ),
      ),
    );
  }
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
