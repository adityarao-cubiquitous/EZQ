import 'package:ezq/features/queue/domain/queue_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves every table in a combined assignment', () {
    final entry = QueueEntry.fromMap('queue-1', {
      'tokenNumber': 12,
      'tokenCode': 'Q12',
      'businessDate': '2026-07-28',
      'customerName': 'Asha',
      'phone': '+919999999999',
      'partySize': 10,
      'partySizeBand': '7+',
      'status': 'seated',
      'assignedTableId': 'table-9',
      'assignedTableNumber': 'F1-T9 + F1-T13',
      'assignedTableIds': ['table-9', 'table-13'],
      'assignedTableNumbers': ['F1-T9', 'F1-T13'],
      'joinedAt': '2026-07-28T12:00:00.000Z',
    });

    expect(entry.assignedTableIds, ['table-9', 'table-13']);
    expect(entry.assignedTableNumbers, ['F1-T9', 'F1-T13']);
    expect(entry.toMap()['assignedTableIds'], ['table-9', 'table-13']);
    expect(entry.copyWith().assignedTableIds, ['table-9', 'table-13']);
  });

  test('maps legacy single-table fields into the assignment lists', () {
    final entry = QueueEntry.fromMap('queue-2', {
      'tokenNumber': 13,
      'tokenCode': 'Q13',
      'businessDate': '2026-07-28',
      'customerName': 'Ravi',
      'phone': '+919999999998',
      'partySize': 4,
      'partySizeBand': '3-4',
      'status': 'seated',
      'assignedTableId': 'table-4',
      'assignedTableNumber': 'F1-T4',
      'joinedAt': '2026-07-28T12:05:00.000Z',
    });

    expect(entry.assignedTableIds, ['table-4']);
    expect(entry.assignedTableNumbers, ['F1-T4']);
  });
}
