import 'package:ezq/core/utils/restaurant_logo_asset.dart';
import 'package:ezq/features/admin/presentation/widgets/admin_branch_identity_pill.dart';
import 'package:ezq/features/customer/presentation/restaurant_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps Salad Studio to its local logo', () {
    expect(
      restaurantLogoAsset('salad-studio-12th-main'),
      restaurantSaladLogoAsset,
    );
  });

  test('maps Pasta Pepper to its local logo', () {
    expect(
      restaurantLogoAsset('pasta-pepper-hal-2nd-stage'),
      restaurantPastaLogoAsset,
    );
  });

  test('normalizes whitespace and casing', () {
    expect(
      restaurantLogoAsset('  SALAD-STUDIO-12TH-MAIN  '),
      restaurantSaladLogoAsset,
    );
  });

  test('uses the default local logo for unknown, null, or empty slugs', () {
    expect(
      restaurantLogoAsset('the-spice-house-indiranagar'),
      restaurantDefaultLogoAsset,
    );
    expect(restaurantLogoAsset(null), restaurantDefaultLogoAsset);
    expect(restaurantLogoAsset('  '), restaurantDefaultLogoAsset);
  });

  testWidgets('customer logo widget resolves assets without stretching', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RestaurantLogo(
          restaurantSlug: 'salad-studio-12th-main',
          size: 66,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, restaurantSaladLogoAsset);
    expect(image.width, 66);
    expect(image.height, 66);
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('admin identity widget uses the Pasta Pepper logo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminBranchIdentityPill(
            restaurantName: 'Pasta Pepper',
            restaurantSlug: 'pasta-pepper-hal-2nd-stage',
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, restaurantPastaLogoAsset);
    expect(image.width, 36);
    expect(image.height, 36);
    expect(image.fit, BoxFit.contain);
  });
}
