import 'package:flutter/material.dart';

import '../constants/restaurant_logo_assets.dart';

export '../constants/restaurant_logo_assets.dart';

enum RestaurantLogoShape { circle, roundedSquare }

class RestaurantLogo extends StatelessWidget {
  const RestaurantLogo({
    super.key,
    required this.restaurantBranchId,
    this.restaurantName,
    this.logoUrl,
    this.size = 72,
    this.shape = RestaurantLogoShape.roundedSquare,
    this.showShadow = true,
  });

  final String restaurantBranchId;
  final String? restaurantName;
  final String? logoUrl;
  final double size;
  final RestaurantLogoShape shape;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final isCircle = shape == RestaurantLogoShape.circle;
    final borderRadius = BorderRadius.circular(size * 0.28);
    final image = _resolvedImage();

    return Semantics(
      image: true,
      label: restaurantName?.trim().isNotEmpty == true
          ? '${restaurantName!.trim()} logo'
          : 'Restaurant logo',
      child: Container(
        key: ValueKey('restaurant-logo-$restaurantBranchId'),
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

  Widget _resolvedImage() {
    final fallback = _initialsOrEzqLogo();
    final normalizedLogoUrl = logoUrl?.trim();
    final parsedLogoUrl = normalizedLogoUrl == null
        ? null
        : Uri.tryParse(normalizedLogoUrl);
    final networkImage =
        normalizedLogoUrl != null &&
            normalizedLogoUrl.isNotEmpty &&
            parsedLogoUrl?.hasScheme == true &&
            (parsedLogoUrl?.scheme == 'https' ||
                parsedLogoUrl?.scheme == 'http')
        ? Image.network(
            normalizedLogoUrl,
            key: ValueKey('restaurant-logo-network-$restaurantBranchId'),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;
    final assetPath = RestaurantLogoAssets.specificForBranch(
      restaurantBranchId,
    );
    if (assetPath == null) return networkImage;
    return Image.asset(
      assetPath,
      key: ValueKey('restaurant-logo-asset-$restaurantBranchId'),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => networkImage,
    );
  }

  Widget _initialsOrEzqLogo() {
    final initials = _restaurantInitials(restaurantName);
    if (initials.isNotEmpty) {
      return ColoredBox(
        key: ValueKey('restaurant-logo-initials-$restaurantBranchId'),
        color: const Color(0xFFE7F8FC),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              color: const Color(0xFF006B7A),
              fontSize: size * 0.34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      key: ValueKey('restaurant-logo-generic-$restaurantBranchId'),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: Image.asset(
          'assets/brand/ezq_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.restaurant_rounded, color: Color(0xFF006B7A)),
        ),
      ),
    );
  }
}

String _restaurantInitials(String? restaurantName) {
  final words = restaurantName
      ?.trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .toList();
  if (words == null || words.isEmpty) return '';
  return words.map((word) => word[0].toUpperCase()).join();
}
