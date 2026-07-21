import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/queue/domain/queue_entry.dart';
import 'package:ezq/features/queue/domain/queue_status.dart';
import 'package:ezq/features/queue/presentation/queue_panel.dart';

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
}
