import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/queue/domain/queue_entry.dart';
import 'package:ezq/features/queue/domain/queue_status.dart';
import 'package:ezq/features/queue/presentation/queue_panel.dart';
import 'package:ezq/features/tables/domain/restaurant_table.dart';
import 'package:ezq/features/tables/domain/table_status.dart';

void main() {
  testWidgets('party name uses a larger complementary chip', (tester) async {
    final entry = QueueEntry(
      id: 'queue-1',
      tokenNumber: 12,
      tokenCode: 'Q12',
      businessDate: '2026-07-21',
      customerName: 'Asha Rao',
      phone: '+919999999999',
      partySize: 4,
      partySizeBand: '3-4',
      status: QueueStatus.waiting,
      estimatedWaitMinutes: 10,
      queuePosition: 1,
      extensionUsed: false,
      joinedAt: DateTime(2026, 7, 21, 12),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            child: QueuePanel(
              queue: [entry],
              availableTables: const [],
              onReserve: (_) {},
              onSkip: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('queue-party-name-chip-queue-1')),
      findsOneWidget,
    );
    final name = tester.widget<Text>(find.text('Asha Rao'));
    expect(name.style?.fontSize, 17);
    expect(name.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('queue card reflows without overflow as panel width changes', (
    tester,
  ) async {
    final entry = QueueEntry(
      id: 'responsive-queue',
      tokenNumber: 108,
      tokenCode: 'Q108',
      businessDate: '2026-07-22',
      customerName: 'An exceptionally long restaurant party name',
      phone: '+919999999998',
      partySize: 8,
      partySizeBand: '7-8',
      status: QueueStatus.waiting,
      estimatedWaitMinutes: 24,
      queuePosition: 1,
      extensionUsed: false,
      joinedAt: DateTime(2026, 7, 22, 12),
    );

    Future<void> pumpAtWidth(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: QueuePanel(
                  queue: [entry],
                  availableTables: const [],
                  onReserve: (_) {},
                  onSkip: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pumpAtWidth(300);
    final narrowReserve = tester.getCenter(find.text('Reserve'));
    final narrowSkip = tester.getCenter(find.text('Skip'));
    expect(narrowSkip.dy, greaterThan(narrowReserve.dy));
    expect(
      find.byKey(const ValueKey('queue-party-name-chip-responsive-queue')),
      findsOneWidget,
    );

    await pumpAtWidth(620);
    final wideReserve = tester.getCenter(find.text('Reserve'));
    final wideSkip = tester.getCenter(find.text('Skip'));
    expect((wideSkip.dy - wideReserve.dy).abs(), lessThan(2));
    expect(wideSkip.dx, greaterThan(wideReserve.dx));
  });

  testWidgets('passes the complete multi-table recommendation on selection', (
    tester,
  ) async {
    final entry = QueueEntry(
      id: 'multi-table-queue',
      tokenNumber: 4,
      tokenCode: 'Q04',
      businessDate: '2026-07-28',
      customerName: 'Large party',
      phone: '+919999999997',
      partySize: 10,
      partySizeBand: '7+',
      status: QueueStatus.waiting,
      estimatedWaitMinutes: 20,
      queuePosition: 1,
      extensionUsed: false,
      joinedAt: DateTime(2026, 7, 28, 12),
    );
    const recommendation = QueueTableRecommendation(
      tableIds: ['table-9', 'table-13'],
      tableNumbers: ['F1-T9', 'F1-T13'],
      openSeats: 10,
      capacity: 10,
      isShared: false,
      tone: QueueTableRecommendationTone.best,
    );
    QueueTableRecommendation? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            child: QueuePanel(
              queue: [entry],
              tableRecommendations: const {
                'multi-table-queue': [recommendation],
              },
              availableTables: const [
                RestaurantTable(
                  id: 'table-9',
                  tableNumber: 'T9',
                  displayTableName: 'F1-T9',
                  capacity: 4,
                  tableType: '4-top',
                  section: 'main',
                  floorId: 'F1',
                  status: TableStatus.available,
                  sortOrder: 9,
                ),
                RestaurantTable(
                  id: 'table-13',
                  tableNumber: 'T13',
                  displayTableName: 'F1-T13',
                  capacity: 6,
                  tableType: '6-top',
                  section: 'main',
                  floorId: 'F1',
                  status: TableStatus.available,
                  sortOrder: 13,
                ),
              ],
              onReserve: (_) {},
              onSkip: (_) {},
              onRecommendationSelected: (_, value) => selected = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Best: Combine F1-T9 + F1-T13 · exact fit'));

    expect(selected, same(recommendation));
    expect(selected?.tableIds, ['table-9', 'table-13']);
  });
}
