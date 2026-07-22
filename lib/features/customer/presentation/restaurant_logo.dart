import 'package:flutter/material.dart';

import '../../../core/utils/restaurant_logo_asset.dart';

class RestaurantLogo extends StatelessWidget {
  const RestaurantLogo({
    super.key,
    required this.restaurantSlug,
    this.size = 72,
  });

  final String? restaurantSlug;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        restaurantLogoAsset(restaurantSlug),
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
