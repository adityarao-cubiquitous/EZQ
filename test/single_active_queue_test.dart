import 'package:ezq/features/customer/data/customer_queue_repository.dart';
import 'package:ezq/features/queue/domain/queue_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pre-seating active statuses block another queue join', () {
    expect(isSingleQueueBlockingStatus(QueueStatus.waiting), isTrue);
    expect(isSingleQueueBlockingStatus(QueueStatus.reserved), isTrue);
    expect(isSingleQueueBlockingStatus(QueueStatus.onTheWay), isTrue);
  });

  test('seated and terminal statuses release another queue join', () {
    expect(isSingleQueueBlockingStatus(QueueStatus.seated), isFalse);
    expect(isSingleQueueBlockingStatus(QueueStatus.cancelled), isFalse);
    expect(isSingleQueueBlockingStatus(QueueStatus.completed), isFalse);
    expect(isSingleQueueBlockingStatus(QueueStatus.skipped), isFalse);
    expect(isSingleQueueBlockingStatus(QueueStatus.noShow), isFalse);
    expect(isSingleQueueBlockingStatus(QueueStatus.expired), isFalse);
  });

  test('current visit remains visible through seating', () {
    expect(isCurrentCustomerVisitStatus(QueueStatus.waiting), isTrue);
    expect(isCurrentCustomerVisitStatus(QueueStatus.reserved), isTrue);
    expect(isCurrentCustomerVisitStatus(QueueStatus.onTheWay), isTrue);
    expect(isCurrentCustomerVisitStatus(QueueStatus.seated), isTrue);
    expect(isCurrentCustomerVisitStatus(QueueStatus.cancelled), isFalse);
    expect(isCurrentCustomerVisitStatus(QueueStatus.completed), isFalse);
  });

  test('home lookup restores and clears the current visit', () async {
    final repository = MockCustomerQueueRepository();
    final request = _request(restaurantBranchId: 'restaurant-a-branch-a');

    expect(await repository.findCurrentVisit(phone: request.phone), isNull);

    await repository.joinQueue(request);
    final restoredVisit = await repository.findCurrentVisit(
      phone: request.phone,
    );
    expect(restoredVisit, isNotNull);
    expect(restoredVisit?.restaurantBranchId, request.restaurantBranchId);
    expect(restoredVisit?.queueEntryId, 'demo-entry');
    expect(
      restoredVisit?.statusRoute,
      '/customer/${request.restaurantBranchId}/status/demo-entry',
    );

    await repository.cancelQueueEntry(
      restaurantBranchId: request.restaurantBranchId,
      queueEntryId: 'demo-entry',
      phone: request.phone,
    );
    expect(await repository.findCurrentVisit(phone: request.phone), isNull);
  });

  test('second restaurant join is blocked until cancellation', () async {
    final repository = MockCustomerQueueRepository();
    final firstJoin = _request(restaurantBranchId: 'restaurant-a-branch-a');
    final secondJoin = _request(restaurantBranchId: 'restaurant-b-branch-b');

    await repository.joinQueue(firstJoin);

    await expectLater(
      repository.joinQueue(secondJoin),
      throwsA(
        isA<ActiveQueueConflictException>().having(
          (error) => error.restaurantBranchId,
          'restaurantBranchId',
          firstJoin.restaurantBranchId,
        ),
      ),
    );

    await repository.cancelQueueEntry(
      restaurantBranchId: firstJoin.restaurantBranchId,
      queueEntryId: 'demo-entry',
      phone: firstJoin.phone,
    );

    await expectLater(repository.joinQueue(secondJoin), completes);
  });

  test('on-the-way customer remains blocked from another join', () async {
    final repository = MockCustomerQueueRepository();
    final firstJoin = _request(restaurantBranchId: 'restaurant-a-branch-a');

    await repository.joinQueue(firstJoin);
    repository.setStatusForTesting(QueueStatus.reserved);
    await repository.markOnTheWay(
      restaurantBranchId: firstJoin.restaurantBranchId,
      queueEntryId: 'demo-entry',
      phone: firstJoin.phone,
    );

    await expectLater(
      repository.joinQueue(
        _request(restaurantBranchId: 'restaurant-b-branch-b'),
      ),
      throwsA(
        isA<ActiveQueueConflictException>().having(
          (error) => error.status,
          'status',
          QueueStatus.onTheWay,
        ),
      ),
    );
  });

  test('customer cancellation is rejected after seating', () async {
    final repository = MockCustomerQueueRepository();
    final request = _request(restaurantBranchId: 'restaurant-a-branch-a');

    await repository.joinQueue(request);
    repository.setStatusForTesting(QueueStatus.seated);

    await expectLater(
      repository.cancelQueueEntry(
        restaurantBranchId: request.restaurantBranchId,
        queueEntryId: 'demo-entry',
        phone: request.phone,
      ),
      throwsStateError,
    );
  });

  test('terminal queue entries cannot transition again', () {
    for (final status in QueueStatus.values.where(
      (status) => status.isTerminal,
    )) {
      expect(
        status.canTransitionTo(QueueStatus.waiting),
        isFalse,
        reason: '${status.wireName} must stay terminal',
      );
      expect(status.canBeCancelledByCustomer, isFalse);
    }
  });
}

JoinQueueRequest _request({required String restaurantBranchId}) {
  return JoinQueueRequest(
    restaurantBranchId: restaurantBranchId,
    customerName: 'Queue Test Customer',
    phone: '9880478370',
    partySize: 2,
    enforceSingleActiveQueue: true,
  );
}
