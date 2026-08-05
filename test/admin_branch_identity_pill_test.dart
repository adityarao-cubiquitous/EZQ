import 'package:ezq/features/admin/presentation/widgets/admin_branch_identity_pill.dart';
import 'package:ezq/features/customer/domain/restaurant_branch_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const identity = RestaurantBranchIdentity(
    restaurantBranchId: 'future-kitchen-central-market',
    restaurantName: 'Future Kitchen',
    branchName: 'Central Market',
  );

  Widget testApp({required Widget child, double width = 560}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  testWidgets(
    'shows canonical restaurant above branch without changing restaurant style',
    (tester) async {
      await tester.pumpWidget(
        testApp(child: const AdminBranchIdentityPill(identity: identity)),
      );

      final restaurantFinder = find.text('Future Kitchen');
      final branchFinder = find.text('Central Market');
      expect(restaurantFinder, findsOneWidget);
      expect(branchFinder, findsOneWidget);
      expect(
        tester.getTopLeft(restaurantFinder).dy,
        lessThan(tester.getTopLeft(branchFinder).dy),
      );

      final restaurantText = tester.widget<Text>(restaurantFinder);
      final branchText = tester.widget<Text>(branchFinder);
      expect(restaurantText.style?.fontFamily, 'Poppins');
      expect(restaurantText.style?.fontSize, 18);
      expect(restaurantText.style?.fontWeight, FontWeight.w600);
      expect(restaurantText.style?.color, Colors.white);
      expect(restaurantText.style?.letterSpacing, 0);
      expect(branchText.style?.fontFamily, restaurantText.style?.fontFamily);
      expect(branchText.style?.fontSize, 12);
      expect(branchText.style?.fontWeight, FontWeight.w400);
      expect(branchText.style?.fontStyle, FontStyle.italic);
      expect(
        branchText.style?.color?.a,
        lessThan(restaurantText.style!.color!.a),
      );
    },
  );

  testWidgets('keeps long canonical names on one line across viewport widths', (
    tester,
  ) async {
    const longIdentity = RestaurantBranchIdentity(
      restaurantBranchId: 'restaurant-with-a-very-long-name-main',
      restaurantName: 'Restaurant With A Very Long Firestore Name',
      branchName: 'Branch With A Very Long Firestore Name',
    );

    for (final viewport in [
      (width: 180.0, compact: true),
      (width: 230.0, compact: true),
      (width: 320.0, compact: true),
      (width: 420.0, compact: false),
      (width: 560.0, compact: false),
    ]) {
      await tester.pumpWidget(
        testApp(
          width: viewport.width,
          child: AdminBranchIdentityPill(
            identity: longIdentity,
            compact: viewport.compact,
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '${viewport.width}px');
    }

    final restaurantText = tester.widget<Text>(
      find.text(longIdentity.restaurantName),
    );
    final branchText = tester.widget<Text>(find.text(longIdentity.branchName));
    expect(restaurantText.maxLines, 1);
    expect(branchText.maxLines, 1);
    expect(restaurantText.overflow, TextOverflow.ellipsis);
    expect(branchText.overflow, TextOverflow.ellipsis);
    expect(restaurantText.style?.fontSize, 18);
    expect(branchText.style?.fontSize, 12);
  });

  testWidgets('reserves the identity hierarchy while Firestore data loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        width: 230,
        child: const AdminBranchIdentityPill.loading(
          restaurantBranchId: 'future-kitchen-central-market',
          compact: true,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(identity.restaurantName), findsNothing);
    expect(find.text(identity.branchName), findsNothing);
    expect(
      find.bySemanticsLabel('Loading restaurant and branch'),
      findsOneWidget,
    );
  });
}
