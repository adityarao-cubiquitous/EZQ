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
      tester.getTopLeft(find.byKey(const ValueKey('floor-0'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('floor-1'))).dy,
    );
  });
}
