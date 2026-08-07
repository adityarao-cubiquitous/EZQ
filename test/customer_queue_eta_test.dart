import 'package:ezq/features/customer/domain/queue_eta.dart';
import 'package:ezq/features/queue/domain/queue_entry.dart';
import 'package:ezq/features/queue/domain/queue_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final joinedAt = DateTime(2026, 8, 6, 12);

  QueueEntry entry({int estimate = 10}) => QueueEntry(
    id: 'eta-entry',
    tokenNumber: 1,
    tokenCode: 'Q01',
    businessDate: '2026-08-06',
    customerName: 'ETA Customer',
    phone: '+919999999999',
    partySize: 2,
    partySizeBand: '1-2',
    status: QueueStatus.waiting,
    estimatedWaitMinutes: estimate,
    queuePosition: 1,
    extensionUsed: false,
    joinedAt: joinedAt,
  );

  test('ETA is stable across refreshes within the same elapsed minute', () {
    final queueEntry = entry();

    expect(
      remainingQueueWaitMinutes(
        queueEntry,
        now: joinedAt.add(const Duration(seconds: 5)),
      ),
      10,
    );
    expect(
      remainingQueueWaitMinutes(
        queueEntry,
        now: joinedAt.add(const Duration(seconds: 55)),
      ),
      10,
    );
  });

  test('ETA derives from wall-clock elapsed time after route recreation', () {
    final queueEntry = entry();

    expect(
      remainingQueueWaitMinutes(
        queueEntry,
        now: joinedAt.add(const Duration(minutes: 3, seconds: 20)),
      ),
      7,
    );
    expect(
      remainingQueueWaitMinutes(
        queueEntry,
        now: joinedAt.add(const Duration(minutes: 30)),
      ),
      0,
    );
  });

  test(
    'backend estimate changes are reflected without resetting elapsed time',
    () {
      expect(
        remainingQueueWaitMinutes(
          entry(estimate: 15),
          now: joinedAt.add(const Duration(minutes: 4)),
        ),
        11,
      );
    },
  );
}
