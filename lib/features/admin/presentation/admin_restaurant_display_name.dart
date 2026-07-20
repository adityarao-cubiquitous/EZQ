import '../../../core/constants/app_constants.dart';

String adminRestaurantDisplayName(String restaurantId) {
  if (restaurantId == AppConstants.demoRestaurantId) return 'The Spice House';
  return restaurantId
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
