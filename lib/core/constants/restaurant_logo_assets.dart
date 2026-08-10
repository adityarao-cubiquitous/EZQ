abstract final class RestaurantLogoAssets {
  static const defaultLogo =
      'assets/restaurant_logos/default_restaurant_logo.png';
  static const noodleYardLogo = 'assets/restaurant_logos/noodle_yard_logo.png';
  static const saladStudioLogo =
      'assets/restaurant_logos/salad_studio_logo.png';

  static const branchAssets = <String, String>{
    'noodle-yard-indiranagar': noodleYardLogo,
    'salad-studio-12th-main': saladStudioLogo,
  };

  static String forBranch(String restaurantBranchId) {
    final normalizedId = restaurantBranchId.trim().toLowerCase();
    if (normalizedId == 'salad-studio' ||
        normalizedId.startsWith('salad-studio-')) {
      return saladStudioLogo;
    }
    return branchAssets[normalizedId] ?? defaultLogo;
  }
}
