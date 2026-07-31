import 'package:ezq/features/rest_onboarding/presentation/widgets/floors_tables_step.dart';
import 'package:ezq/features/rest_onboarding/presentation/widgets/table_configuration_matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in <Size>[
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 1200),
  ]) {
    testWidgets('matrix shows table and seat totals at ${size.width}px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TableConfigurationMatrix(
                title: 'Table Configuration Matrix',
                selectedCapacities: <int>[2, 4],
                tableCountsByFloor: <List<int>>[
                  <int>[4, 2],
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(RegExp(r'Floor 1, 2 Top, 4 tables, 8 seats')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Floor 1, 4 Top, 2 tables, 8 seats')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Floor 1 total, 6 tables, 16 seats')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Grand total, 6 tables, 16 seats')),
        findsOneWidget,
      );
    });
  }

  testWidgets('editable matrix updates represented seats live', (tester) async {
    var counts = <List<int>>[
      <int>[4, 2],
    ];

    await tester.binding.setSurfaceSize(const Size(820, 1180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return FloorsTablesStep(
                floorCount: 1,
                selectedTableCapacities: const <int>[2, 4],
                tableCountsByFloor: counts,
                showValidationError: false,
                canContinue: true,
                onFloorCountChanged: (_) {},
                onTableCapacityAdded: (_) {},
                onTableCapacityRemoved: (_) {},
                onTableCountChanged: (floorIndex, tableTypeIndex, value) {
                  setState(() {
                    counts = [
                      [...counts.first]..[tableTypeIndex] = value,
                    ];
                  });
                },
                onBack: () {},
                onSaveDraft: () {},
                onContinue: () {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(RegExp(r'Floor 1, 2 Top, 4 tables, 8 seats')),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Grand total, 6 tables, 16 seats')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('floor-1-cap-2-count-4')),
    );
    await tester.tap(find.byKey(const ValueKey('floor-1-cap-2-count-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel(RegExp(r'Floor 1, 2 Top, 5 tables, 10 seats')),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Grand total, 7 tables, 18 seats')),
      findsOneWidget,
    );
  });
}
