import 'package:flutter/material.dart';

import '../constants/restaurant_logo_assets.dart';

export '../constants/restaurant_logo_assets.dart';

enum RestaurantLogoShape { circle, roundedSquare }

class RestaurantLogo extends StatelessWidget {
  const RestaurantLogo({
    super.key,
    required this.restaurantBranchId,
    this.size = 72,
    this.shape = RestaurantLogoShape.roundedSquare,
    this.showShadow = true,
  });

  final String restaurantBranchId;
  final double size;
  final RestaurantLogoShape shape;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final isCircle = shape == RestaurantLogoShape.circle;
    final assetPath = RestaurantLogoAssets.forBranch(restaurantBranchId);
    final borderRadius = BorderRadius.circular(size * 0.28);

    final image = Image.asset(
      assetPath,
      key: ValueKey('restaurant-logo-$restaurantBranchId'),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(
          color: Colors.white,
          child: Icon(Icons.restaurant_rounded, color: Color(0xFF006B7A)),
        );
      },
    );

    return Semantics(
      image: true,
      label: 'Restaurant logo',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(isCircle ? 2 : 0),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : borderRadius,
          border: Border.all(color: Colors.white, width: isCircle ? 2 : 3),
          boxShadow: showShadow
              ? const [
                  BoxShadow(
                    color: Color(0x1A12A9DC),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: isCircle
            ? ClipOval(child: image)
            : ClipRRect(borderRadius: borderRadius, child: image),
      ),
    );
  }
}
