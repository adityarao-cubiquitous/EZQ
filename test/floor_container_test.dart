import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/tables/presentation/table_grid.dart';

void main() {
  testWidgets('floor card uses a solid premium outline and top accent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: FloorContainer(
              key: ValueKey('floor-card'),
              floorLabel: 'Ground Floor (6 Tables)',
              compact: false,
              child: SizedBox(height: 160),
            ),
          ),
        ),
      ),
    );

    final containers = tester.widgetList<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('floor-card')),
        matching: find.byType(Container),
      ),
    );
    final card = containers.firstWhere(
      (container) =>
          container.decoration is BoxDecoration &&
          (container.decoration! as BoxDecoration).border != null,
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.border!.top.style, BorderStyle.solid);
    expect(decoration.border!.top.color, const Color(0xFFD9E2EC));
    expect(decoration.borderRadius, BorderRadius.circular(20));
    expect(find.byKey(const ValueKey('floor-card-accent')), findsOneWidget);
  });
}
