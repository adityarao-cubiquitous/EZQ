import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/core/constants/app_colors.dart';
import 'package:ezq/features/admin/presentation/widgets/admin_branch_identity_pill.dart';

void main() {
  testWidgets('uses the enabled Walk-in button colors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminBranchIdentityPill(
            restaurantName: 'The Spice House',
            restaurantSlug: 'the-spice-house-indiranagar',
          ),
        ),
      ),
    );

    final gradientContainers = find.byWidgetPredicate((widget) {
      if (widget is! Container || widget.decoration is! BoxDecoration) {
        return false;
      }
      final decoration = widget.decoration! as BoxDecoration;
      return decoration.gradient == AppColors.primaryGradient;
    });
    final restaurantName = tester.widget<Text>(find.text('The Spice House'));

    expect(gradientContainers, findsOneWidget);
    expect(restaurantName.style?.color, Colors.white);
    expect(find.byType(ShaderMask), findsNothing);
  });
}
