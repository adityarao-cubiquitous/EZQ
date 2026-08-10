import 'package:ezq/features/customer/domain/branch.dart';
import 'package:ezq/features/customer/presentation/customer_restaurant_identity.dart';
import 'package:ezq/core/widgets/restaurant_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('branch identity resolves all customer branding fields once', () {
    final branch = Branch.fromMap('salad-studio-12th-main', {
      'restaurantName': 'Salad Studio',
      'branchName': '12th Main',
      'address': '12th Main Road, Indiranagar, Bengaluru',
      'logoUrl': 'https://example.com/salad-studio.png',
      'isActive': true,
    });

    expect(branch.identity.restaurantBranchId, 'salad-studio-12th-main');
    expect(branch.identity.restaurantName, 'Salad Studio');
    expect(branch.identity.branchLabel, '12th Main Branch');
    expect(
      branch.identity.addressLabel,
      '12th Main Road, Indiranagar, Bengaluru',
    );
    expect(branch.identity.logoUrl, 'https://example.com/salad-studio.png');
    expect(branch.identity.initials, 'SS');
  });

  testWidgets('shared identity view renders consistent customer branding', (
    tester,
  ) async {
    final identity = Branch.fromMap('noodle-yard-indiranagar', {
      'restaurantName': 'Noodle Yard',
      'branchName': 'Indiranagar',
      'address': '12th Main Road, Indiranagar, Bengaluru',
      'isActive': true,
    }).identity;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerRestaurantIdentityView(identity: identity),
        ),
      ),
    );

    expect(find.text('Noodle Yard'), findsOneWidget);
    expect(find.text('Indiranagar Branch'), findsOneWidget);
    expect(find.text('12th Main Road, Indiranagar, Bengaluru'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('restaurant-logo-asset-noodle-yard-indiranagar'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('missing address and logo keep branding usable', (tester) async {
    final identity = Branch.fromMap('legacy-cafe-main', {
      'restaurantName': 'Legacy Cafe',
      'branchName': 'Main',
      'isActive': true,
    }).identity;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerRestaurantIdentityView(identity: identity),
        ),
      ),
    );

    expect(find.text('Legacy Cafe'), findsOneWidget);
    expect(find.text('Main Branch'), findsOneWidget);
    expect(find.text('Address unavailable'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      RestaurantLogoAssets.defaultLogo,
    );
    expect(tester.takeException(), isNull);
  });
}
