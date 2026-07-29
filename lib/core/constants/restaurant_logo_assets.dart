abstract final class RestaurantLogoAssets {
  static const defaultLogo = 'assets/restaurant_logos/default.png';
  static const noodleYardLogo = 'assets/restaurant_logos/noodle_yard_logo.png';
  static const saladStudioLogo =
      'assets/restaurant_logos/salad_studio_logo.png';

  static const branchAssets = <String, String>{
    'bhagini-horamavu-signal': defaultLogo,
    'biryani-bay-domlur-edge': defaultLogo,
    'codex-rule-sync-cafe-00wh77-main': defaultLogo,
    'cubbon-curry-indiranagar': defaultLogo,
    'dosa-lab-indiranagar': defaultLogo,
    'grill-garden-old-airport-road': defaultLogo,
    'mahanagaram-kalyan-nagar': defaultLogo,
    'momo-mill-indiranagar-metro': defaultLogo,
    'noodle-yard-indiranagar': noodleYardLogo,
    'pasta-pepper-hal-2nd-stage': defaultLogo,
    'salad-studio-12th-main': saladStudioLogo,
    'taco-tawa-indiranagar': defaultLogo,
    'tamarind-banaswadi': defaultLogo,
    'the-filter-coffee-kalyan-nagar': defaultLogo,
    'the-indian-eatery-kalyan-nagar': defaultLogo,
    'the-spice-house-indiranagar': defaultLogo,
  };

  static String forBranch(String restaurantBranchId) {
    final normalizedId = restaurantBranchId.trim().toLowerCase();
    return branchAssets[normalizedId] ?? defaultLogo;
  }
}
