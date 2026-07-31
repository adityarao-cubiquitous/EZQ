import 'dart:async';

import 'package:ezq/features/customer/data/branch_identity_repository.dart';
import 'package:ezq/features/customer/data/customer_queue_repository.dart';
import 'package:ezq/features/customer/domain/party_ahead_copy.dart';
import 'package:ezq/features/customer/presentation/customer_queue_status_screen.dart';
import 'package:ezq/features/queue/domain/queue_entry.dart';
import 'package:ezq/features/queue/domain/queue_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const restaurantId = 'state-machine-restaurant';
  const branchId = 'state-machine-branch';
  const queueEntryId = 'state-machine-entry';

  Future<void> pumpStatusScreen(
    WidgetTester tester,
    ControlledCustomerQueueRepository repository, {
    Size size = const Size(430, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerQueueRepositoryProvider.overrideWithValue(repository),
          branchIdentityRepositoryProvider.overrideWithValue(
            PassthroughBranchIdentityRepository(),
          ),
        ],
        child: const MaterialApp(
          home: CustomerQueueStatusScreen(
            restaurantId: restaurantId,
            branchId: branchId,
            queueEntryId: queueEntryId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  final expectations = <QueueStatus, ({String key, String text})>{
    QueueStatus.waiting: (key: 'queue-status-waiting', text: 'Ahead'),
    QueueStatus.reserved: (
      key: 'queue-status-reserved',
      text: 'Your table is ready!',
    ),
    QueueStatus.onTheWay: (
      key: 'queue-status-on_the_way',
      text: "We'll see you soon!",
    ),
    QueueStatus.seated: (key: 'queue-status-seated', text: 'Enjoy your meal!'),
    QueueStatus.completed: (
      key: 'queue-status-completed',
      text: '✓ Meal Completed',
    ),
    QueueStatus.cancelled: (
      key: 'queue-status-cancelled',
      text: 'Queue Exited',
    ),
    QueueStatus.skipped: (
      key: 'queue-status-skipped',
      text: 'Reservation Skipped',
    ),
    QueueStatus.noShow: (
      key: 'queue-status-no_show',
      text: 'Reservation Closed',
    ),
    QueueStatus.expired: (
      key: 'queue-status-expired',
      text: 'Q42 exited the queue',
    ),
  };

  for (final status in QueueStatus.values) {
    testWidgets('${status.wireName} has an explicit deterministic renderer', (
      tester,
    ) async {
      final repository = ControlledCustomerQueueRepository(status);
      addTearDown(repository.close);

      await pumpStatusScreen(tester, repository);

      final expected = expectations[status]!;
      expect(find.byKey(ValueKey(expected.key)), findsOneWidget);
      expect(find.text(expected.text), findsOneWidget);
      expect(
        find.byKey(const ValueKey('queue-status-cancel-action')),
        status.canBeCancelledByCustomer ? findsOneWidget : findsNothing,
      );
      if (status.isTerminal) {
        expect(
          find.byKey(const ValueKey('queue-status-waiting')),
          findsNothing,
        );
        expect(find.text('Ahead'), findsNothing);
        expect(
          find.byKey(const ValueKey('queue-status-join-again')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('waiting uses Party and Parties for the live ahead count', (
    tester,
  ) async {
    for (final (count, noun) in <(int, String)>[(1, 'Party'), (5, 'Parties')]) {
      final repository = ControlledCustomerQueueRepository(
        QueueStatus.waiting,
        aheadCount: count,
      );
      await pumpStatusScreen(tester, repository);

      expect(find.text('$count'), findsOneWidget);
      expect(find.text(noun), findsOneWidget);
      expect(find.text('person'), findsNothing);
      expect(find.text('people'), findsNothing);
      await repository.close();
    }
  });

  test('party-ahead copy uses correct singular and plural grammar', () {
    expect(partiesAheadLabel(1), '1 Party Ahead');
    expect(partiesAheadLabel(5), '5 Parties Ahead');
    expect(partiesAheadLabel(0), '0 Parties Ahead');
  });

  testWidgets('completed and cancelled states offer restaurant browsing', (
    tester,
  ) async {
    for (final status in [QueueStatus.completed, QueueStatus.cancelled]) {
      final repository = ControlledCustomerQueueRepository(status);
      await pumpStatusScreen(tester, repository);
      expect(
        find.byKey(const ValueKey('queue-status-browse-restaurants')),
        findsOneWidget,
      );
      await repository.close();
    }
  });

  testWidgets('waiting changes to cancelled without a refresh', (tester) async {
    final semantics = tester.ensureSemantics();
    final repository = ControlledCustomerQueueRepository(QueueStatus.waiting);
    addTearDown(repository.close);
    await pumpStatusScreen(tester, repository);

    expect(
      tester
          .getSemantics(
            find.descendant(
              of: find.byKey(
                const ValueKey('queue-status-cancel-action'),
              ),
              matching: find.byType(OutlinedButton),
            ),
          )
          .label,
      'Exit Queue',
    );
    semantics.dispose();
    await tester.tap(find.text('Exit Queue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('queue-status-cancelled')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('queue-status-waiting')), findsNothing);
    expect(find.text('You have exited the queue.'), findsOneWidget);
  });

  testWidgets('manager completion updates the customer in realtime', (
    tester,
  ) async {
    final repository = ControlledCustomerQueueRepository(QueueStatus.waiting);
    addTearDown(repository.close);
    await pumpStatusScreen(tester, repository);

    repository.emitStatus(QueueStatus.completed);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('queue-status-completed')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('queue-status-waiting')), findsNothing);
  });

  testWidgets('host skip and no-show update the customer in realtime', (
    tester,
  ) async {
    final repository = ControlledCustomerQueueRepository(QueueStatus.waiting);
    addTearDown(repository.close);
    await pumpStatusScreen(tester, repository);

    repository.emitStatus(QueueStatus.skipped);
    await tester.pump();
    expect(find.byKey(const ValueKey('queue-status-skipped')), findsOneWidget);

    repository.emitStatus(QueueStatus.noShow);
    await tester.pump();
    expect(find.byKey(const ValueKey('queue-status-no_show')), findsOneWidget);
    expect(find.byKey(const ValueKey('queue-status-waiting')), findsNothing);
  });

  testWidgets('direct deep link renders the persisted terminal status', (
    tester,
  ) async {
    final repository = ControlledCustomerQueueRepository(QueueStatus.cancelled);
    addTearDown(repository.close);
    final router = GoRouter(
      initialLocation: '/customer/$branchId/status/$queueEntryId',
      routes: [
        GoRoute(
          path: '/customer/:branchId/status/:queueEntryId',
          builder: (context, state) => CustomerQueueStatusScreen(
            restaurantId: state.pathParameters['branchId']!,
            branchId: state.pathParameters['branchId']!,
            queueEntryId: state.pathParameters['queueEntryId']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerQueueRepositoryProvider.overrideWithValue(repository),
          branchIdentityRepositoryProvider.overrideWithValue(
            PassthroughBranchIdentityRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('queue-status-cancelled')),
      findsOneWidget,
    );
  });

  testWidgets('browser and mobile reload reconstruct terminal status', (
    tester,
  ) async {
    var repository = ControlledCustomerQueueRepository(QueueStatus.completed);
    await pumpStatusScreen(tester, repository);
    expect(
      find.byKey(const ValueKey('queue-status-completed')),
      findsOneWidget,
    );
    await repository.close();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    repository = ControlledCustomerQueueRepository(QueueStatus.completed);
    addTearDown(repository.close);
    await pumpStatusScreen(tester, repository, size: const Size(390, 844));

    expect(
      find.byKey(const ValueKey('queue-status-completed')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('queue-status-waiting')), findsNothing);
  });

  testWidgets('stream mapping errors render an error instead of waiting', (
    tester,
  ) async {
    final repository = ControlledCustomerQueueRepository(
      QueueStatus.waiting,
      streamError: const FormatException('Unknown queue status "mystery".'),
    );
    addTearDown(repository.close);

    await pumpStatusScreen(tester, repository);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('queue-status-error')), findsOneWidget);
    expect(find.textContaining('Unknown queue status'), findsOneWidget);
    expect(find.byKey(const ValueKey('queue-status-waiting')), findsNothing);
  });
}

class ControlledCustomerQueueRepository implements CustomerQueueRepository {
  ControlledCustomerQueueRepository(
    QueueStatus initialStatus, {
    this.streamError,
    this.aheadCount = 2,
  }) : _entry = _entryFor(initialStatus);

  final Object? streamError;
  final int aheadCount;
  final StreamController<QueueEntry> _controller =
      StreamController<QueueEntry>.broadcast();
  QueueEntry _entry;

  void emitStatus(QueueStatus status) {
    _entry = _entry.copyWith(status: status);
    _controller.add(_entry);
  }

  Future<void> close() => _controller.close();

  @override
  Future<void> cancelQueueEntry({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  }) async {
    if (!_entry.status.canBeCancelledByCustomer) {
      throw StateError('Cancellation is not permitted.');
    }
    emitStatus(QueueStatus.cancelled);
  }

  @override
  Future<void> extendHold({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  }) async {}

  @override
  Future<ActiveQueueConflictException?> findActiveQueueEntry({
    required String phone,
    String? customerId,
  }) async {
    return null;
  }

  @override
  Future<CustomerQueueVisit?> findCurrentVisit({
    required String phone,
    String? customerId,
  }) async {
    return null;
  }

  @override
  Future<JoinQueueResult> joinQueue(JoinQueueRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<void> markOnTheWay({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  }) async {
    emitStatus(QueueStatus.onTheWay);
  }

  @override
  Stream<int> watchQueueAheadCount({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  }) async* {
    yield aheadCount;
  }

  @override
  Stream<QueueEntry> watchQueueEntry({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  }) async* {
    final error = streamError;
    if (error != null) throw error;
    yield _entry;
    yield* _controller.stream;
  }

  static QueueEntry _entryFor(QueueStatus status) {
    return QueueEntry(
      id: 'state-machine-entry',
      tokenNumber: 42,
      tokenCode: 'Q42',
      businessDate: '2026-07-29',
      customerName: 'State Machine Customer',
      phone: '+919999999999',
      partySize: 4,
      partySizeBand: '3-4',
      status: status,
      assignedTableId: 'table-4',
      assignedTableNumber: 'F1-T4',
      estimatedWaitMinutes: 12,
      queuePosition: 3,
      extensionUsed: false,
      joinedAt: DateTime(2026, 7, 29, 12),
    );
  }
}
