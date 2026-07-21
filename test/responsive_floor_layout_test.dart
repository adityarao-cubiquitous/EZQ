import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/tables/presentation/responsive_floor_layout.dart';

void main() {
  testWidgets('multiple floors remain in one horizontally scrollable row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: ResponsiveFloorGrid(
                itemCount: 2,
                minItemWidth: 220,
                itemGap: 16,
                itemBuilder: (context, index, width) => SizedBox(
                  key: ValueKey('floor-$index'),
                  height: 120,
                  child: Text('Floor $index'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(
      tester.widget<Scrollbar>(find.byType(Scrollbar)).trackVisibility,
      isTrue,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('floor-0'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('floor-1'))).dy,
    );

    final initialSecondFloorX = tester
        .getTopLeft(find.byKey(const ValueKey('floor-1')))
        .dx;
    await tester.drag(
      find.byKey(const ValueKey('floor-horizontal-scroll')),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('floor-1'))).dx,
      lessThan(initialSecondFloorX),
    );
  });

  testWidgets('floor cards keep content-sized widths on a wide dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 1000,
              child: ResponsiveFloorGrid(
                itemCount: 2,
                minItemWidth: 160,
                itemGap: 18,
                itemWidthBuilder: (index) => index == 0 ? 160 : 290,
                itemBuilder: (context, index, width) => SizedBox(
                  key: ValueKey('compact-floor-$index'),
                  height: 120,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('compact-floor-0'))).width,
      160,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('compact-floor-1'))).width,
      290,
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
  });
}
