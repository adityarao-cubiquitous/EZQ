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
    expect(
      RestaurantLogoAssets.forBranch('the-spice-house-indiranagar'),
      RestaurantLogoAssets.defaultLogo,
    );
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

  testWidgets('default asset overrides remote branding for unmapped branches', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RestaurantLogo(
            restaurantBranchId: 'future-restaurant-main',
            restaurantName: 'Future Restaurant',
            logoUrl: 'https://example.com/future.png',
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      RestaurantLogoAssets.defaultLogo,
    );
  });

  testWidgets('default asset replaces initials for unmapped branches', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RestaurantLogo(
            restaurantBranchId: 'future-restaurant-main',
            restaurantName: 'Future Restaurant',
            logoUrl: 'not-a-url',
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      RestaurantLogoAssets.defaultLogo,
    );
  });

  testWidgets('generic branches use the default restaurant logo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RestaurantLogo(restaurantBranchId: 'legacy-branch'),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      RestaurantLogoAssets.defaultLogo,
    );
  });
}
