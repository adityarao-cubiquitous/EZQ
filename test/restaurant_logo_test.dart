import 'package:ezq/core/widgets/restaurant_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restaurant branches resolve to their mapped logo assets', () {
    expect(
      RestaurantLogoAssets.forBranch('salad-studio-12th-main'),
      RestaurantLogoAssets.saladStudioLogo,
    );
    expect(
      RestaurantLogoAssets.forBranch('noodle-yard-indiranagar'),
      RestaurantLogoAssets.noodleYardLogo,
    );

    for (final entry in RestaurantLogoAssets.branchAssets.entries) {
      if (entry.key == 'salad-studio-12th-main' ||
          entry.key == 'noodle-yard-indiranagar') {
        continue;
      }
      expect(entry.value, RestaurantLogoAssets.defaultLogo);
    }
  });

  test('unknown and normalized branch ids use deterministic mapping', () {
    expect(
      RestaurantLogoAssets.forBranch('  NOODLE-YARD-INDIRANAGAR  '),
      RestaurantLogoAssets.noodleYardLogo,
    );
    expect(
      RestaurantLogoAssets.forBranch('future-restaurant-main'),
      RestaurantLogoAssets.defaultLogo,
    );
  });

  testWidgets('restaurant logo renders the resolved asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RestaurantLogo(restaurantBranchId: 'salad-studio-12th-main'),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, RestaurantLogoAssets.saladStudioLogo);
  });
}
