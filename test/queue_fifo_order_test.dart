import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/queue/domain/queue_entry.dart';
import 'package:ezq/features/queue/domain/queue_status.dart';

void main() {
  group('compareQueueEntriesByFifo', () {
    test('orders oldest joinedAt first even when token numbers differ', () {
      final now = DateTime(2026, 6, 25, 18);
      final newerLowerToken = _entry(
        id: 'newer',
        tokenNumber: 1,
        tokenCode: 'Q01',
        joinedAt: now.subtract(const Duration(minutes: 5)),
      );
      final olderHigherToken = _entry(
        id: 'older',
        tokenNumber: 4,
        tokenCode: 'Q04',
        joinedAt: now.subtract(const Duration(minutes: 25)),
      );

      final queue = [newerLowerToken, olderHigherToken]
        ..sort(compareQueueEntriesByFifo);

      expect(queue.map((entry) => entry.tokenCode), ['Q04', 'Q01']);
    });

    test('uses token number as a deterministic tie breaker', () {
      final joinedAt = DateTime(2026, 6, 25, 18);
      final queue = [
        _entry(id: 'q2', tokenNumber: 2, tokenCode: 'Q02', joinedAt: joinedAt),
        _entry(id: 'q1', tokenNumber: 1, tokenCode: 'Q01', joinedAt: joinedAt),
      ]..sort(compareQueueEntriesByFifo);

      expect(queue.map((entry) => entry.tokenCode), ['Q01', 'Q02']);
    });
  });

  group('QueueEntry wait start', () {
    test('joinedAt defines waiting time', () {
      final joinedAt = DateTime(2026, 6, 25, 17, 30);
      final entry = _entry(id: 'q1', joinedAt: joinedAt);

      expect(entry.waitingMinutesSince(DateTime(2026, 6, 25, 18)), 30);
    });

    test('createdAt is used as a legacy fallback when joinedAt is absent', () {
      final createdAt = DateTime(2026, 6, 25, 17, 45);
      final entry = QueueEntry.fromMap('q1', {
        'tokenNumber': 1,
        'tokenCode': 'Q01',
        'businessDate': '2026-06-25',
        'customerName': 'Asha',
        'phone': '+919876543210',
        'partySize': 2,
        'partySizeBand': '1-2',
        'status': 'waiting',
        'estimatedWaitMinutes': 10,
        'queuePosition': 1,
        'extensionUsed': false,
        'createdAt': createdAt.toIso8601String(),
      });

      expect(entry.joinedAt, createdAt);
      expect(entry.waitingMinutesSince(DateTime(2026, 6, 25, 18)), 15);
    });
  });

  test('countQueueEntriesAhead follows the live FIFO queue', () {
    final joinedAt = DateTime(2026, 6, 25, 18);
    final queue = [
      _entry(
        id: 'q4',
        tokenNumber: 4,
        tokenCode: 'Q04',
        joinedAt: joinedAt.add(const Duration(minutes: 3)),
      ),
      _entry(id: 'q1', tokenNumber: 1, tokenCode: 'Q01', joinedAt: joinedAt),
      _entry(
        id: 'q3',
        tokenNumber: 3,
        tokenCode: 'Q03',
        joinedAt: joinedAt.add(const Duration(minutes: 2)),
      ),
      _entry(
        id: 'q2',
        tokenNumber: 2,
        tokenCode: 'Q02',
        joinedAt: joinedAt.add(const Duration(minutes: 1)),
      ),
    ];

    expect(countQueueEntriesAhead(queue, currentEntryId: 'q4'), 3);
    expect(
      countQueueEntriesAhead(
        queue.where((entry) => entry.id != 'q2').toList(),
        currentEntryId: 'q4',
      ),
      2,
    );
  });
}

QueueEntry _entry({
  required String id,
  int tokenNumber = 1,
  String tokenCode = 'Q01',
  QueueStatus status = QueueStatus.waiting,
  DateTime? joinedAt,
}) {
  return QueueEntry(
    id: id,
    tokenNumber: tokenNumber,
    tokenCode: tokenCode,
    businessDate: '2026-06-25',
    customerName: 'Guest',
    phone: '+919876543210',
    partySize: 2,
    partySizeBand: '1-2',
    status: status,
    estimatedWaitMinutes: 10,
    queuePosition: tokenNumber,
    extensionUsed: false,
    joinedAt: joinedAt ?? DateTime(2026, 6, 25, 18),
  );
}
