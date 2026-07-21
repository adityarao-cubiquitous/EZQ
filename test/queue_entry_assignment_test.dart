import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/queue/domain/queue_entry.dart';

void main() {
  test('preserves every table in a combined assignment', () {
    final entry = QueueEntry.fromMap('queue-1', {
      'tokenNumber': 12,
      'tokenCode': 'Q12',
      'businessDate': '2026-07-21',
      'customerName': 'Asha',
      'phone': '+919999999999',
      'partySize': 7,
      'partySizeBand': '7-8',
      'status': 'seated',
      'assignedTableId': 'table-1',
      'assignedTableNumber': 'F1-T1 + F1-T2',
      'assignedTableIds': ['table-1', 'table-2'],
      'assignedTableNumbers': ['F1-T1', 'F1-T2'],
      'joinedAt': '2026-07-21T12:00:00.000Z',
    });

    expect(entry.assignedTableIds, ['table-1', 'table-2']);
    expect(entry.assignedTableNumbers, ['F1-T1', 'F1-T2']);
    expect(entry.toMap()['assignedTableIds'], ['table-1', 'table-2']);
    expect(entry.copyWith().assignedTableIds, ['table-1', 'table-2']);
  });
}
