const restaurantSaladLogoAsset = 'assets/brand/restaurant_salad.png';
const restaurantPastaLogoAsset = 'assets/brand/restaurant_logo_2.png';
const restaurantDefaultLogoAsset = 'assets/brand/restaurant_default_logo.png';

String restaurantLogoAsset(String? restaurantSlug) {
  return switch (restaurantSlug?.trim().toLowerCase()) {
    'salad-studio-12th-main' => restaurantSaladLogoAsset,
    'pasta-pepper-hal-2nd-stage' => restaurantPastaLogoAsset,
    _ => restaurantDefaultLogoAsset,
  };
}
