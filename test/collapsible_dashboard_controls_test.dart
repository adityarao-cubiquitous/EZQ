import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/admin/presentation/widgets/collapsible_dashboard_controls.dart';

void main() {
  testWidgets('phone-landscape controls default collapsed and animate open', (
    tester,
  ) async {
    var expanded = false;
    var changeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollapsibleDashboardControls(
            enabled: true,
            expanded: expanded,
            onExpandedChanged: (value) {
              expanded = value;
              changeCount++;
            },
            child: const SizedBox(
              key: ValueKey('dashboard-controls-content'),
              height: 120,
              child: Text('Free Occupied Waiting Walk-in Offline Enable'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Dashboard Controls'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dashboard-controls-content')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('dashboard-controls-toggle')));
    await tester.pump();

    expect(expanded, isTrue);
    expect(changeCount, 1);
    expect(
      find.byKey(const ValueKey('dashboard-controls-content')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dashboard-controls-toggle')));
    await tester.pumpAndSettle();

    expect(expanded, isFalse);
    expect(changeCount, 2);
    expect(
      find.byKey(const ValueKey('dashboard-controls-content')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('controls remain unchanged when collapsing is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollapsibleDashboardControls(
            enabled: false,
            expanded: false,
            onExpandedChanged: (_) {},
            child: const Text('Existing dashboard controls'),
          ),
        ),
      ),
    );

    expect(find.text('Existing dashboard controls'), findsOneWidget);
    expect(find.text('Dashboard Controls'), findsNothing);
    expect(
      find.byKey(const ValueKey('dashboard-controls-toggle')),
      findsNothing,
    );
  });
}
