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
    final request = _request(
      restaurantId: 'restaurant-a',
      branchId: 'branch-a',
    );

    expect(await repository.findCurrentVisit(phone: request.phone), isNull);

    await repository.joinQueue(request);
    final restoredVisit = await repository.findCurrentVisit(
      phone: request.phone,
    );
    expect(restoredVisit, isNotNull);
    expect(restoredVisit?.queueEntryId, 'demo-entry');
    expect(restoredVisit?.statusRoute, contains('/status/demo-entry'));

    await repository.cancelQueueEntry(
      restaurantId: request.restaurantId,
      branchId: request.branchId,
      queueEntryId: 'demo-entry',
      phone: request.phone,
    );
    expect(await repository.findCurrentVisit(phone: request.phone), isNull);
  });

  test('second restaurant join is blocked until cancellation', () async {
    final repository = MockCustomerQueueRepository();
    final firstJoin = _request(
      restaurantId: 'restaurant-a',
      branchId: 'branch-a',
    );
    final secondJoin = _request(
      restaurantId: 'restaurant-b',
      branchId: 'branch-b',
    );

    await repository.joinQueue(firstJoin);

    await expectLater(
      repository.joinQueue(secondJoin),
      throwsA(isA<ActiveQueueConflictException>()),
    );

    await repository.cancelQueueEntry(
      restaurantId: firstJoin.restaurantId,
      branchId: firstJoin.branchId,
      queueEntryId: 'demo-entry',
      phone: firstJoin.phone,
    );

    await expectLater(repository.joinQueue(secondJoin), completes);
  });

  test('on-the-way customer remains blocked from another join', () async {
    final repository = MockCustomerQueueRepository();
    final firstJoin = _request(
      restaurantId: 'restaurant-a',
      branchId: 'branch-a',
    );

    await repository.joinQueue(firstJoin);
    await repository.markOnTheWay(
      restaurantId: firstJoin.restaurantId,
      branchId: firstJoin.branchId,
      queueEntryId: 'demo-entry',
      phone: firstJoin.phone,
    );

    await expectLater(
      repository.joinQueue(
        _request(restaurantId: 'restaurant-b', branchId: 'branch-b'),
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
}

JoinQueueRequest _request({
  required String restaurantId,
  required String branchId,
}) {
  return JoinQueueRequest(
    restaurantId: restaurantId,
    branchId: branchId,
    customerName: 'Queue Test Customer',
    phone: '9880478370',
    partySize: 2,
    enforceSingleActiveQueue: true,
  );
}
