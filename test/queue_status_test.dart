import 'package:ezq/features/queue/domain/queue_entry.dart';
import 'package:ezq/features/queue/domain/queue_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every supported wire status maps exactly', () {
    for (final status in QueueStatus.values) {
      expect(QueueStatus.fromWireName(status.wireName), status);
    }
  });

  test('unknown and missing wire statuses never become waiting', () {
    expect(
      () => QueueStatus.fromWireName('mystery_status'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => QueueStatus.fromWireName(null),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => QueueEntry.fromMap('unknown-entry', {'status': 'mystery_status'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('only pre-seating statuses permit customer cancellation', () {
    expect(QueueStatus.waiting.canBeCancelledByCustomer, isTrue);
    expect(QueueStatus.reserved.canBeCancelledByCustomer, isTrue);
    expect(QueueStatus.onTheWay.canBeCancelledByCustomer, isTrue);

    expect(QueueStatus.seated.canBeCancelledByCustomer, isFalse);
    expect(QueueStatus.completed.canBeCancelledByCustomer, isFalse);
    expect(QueueStatus.cancelled.canBeCancelledByCustomer, isFalse);
    expect(QueueStatus.skipped.canBeCancelledByCustomer, isFalse);
    expect(QueueStatus.noShow.canBeCancelledByCustomer, isFalse);
    expect(QueueStatus.expired.canBeCancelledByCustomer, isFalse);
  });

  test('host can mark a waiting customer as skipped or no-show', () {
    expect(QueueStatus.waiting.canTransitionTo(QueueStatus.skipped), isTrue);
    expect(QueueStatus.waiting.canTransitionTo(QueueStatus.noShow), isTrue);
  });
}
