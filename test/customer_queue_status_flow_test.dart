import 'dart:async';

import 'package:ezq/features/auth/data/auth_repository.dart';
import 'package:ezq/features/customer/data/branch_identity_repository.dart';
import 'package:ezq/features/customer/data/customer_queue_repository.dart';
import 'package:ezq/features/customer/domain/party_ahead_copy.dart';
import 'package:ezq/features/customer/presentation/customer_app_home_screen.dart';
import 'package:ezq/features/customer/presentation/customer_queue_status_screen.dart';
import 'package:ezq/features/queue/domain/queue_entry.dart';
import 'package:ezq/features/queue/domain/queue_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const restaurantBranchId = 'state-machine-restaurant-state-machine-branch';
  const queueEntryId = 'state-machine-entry';

  Future<void> pumpStatusScreen(
    WidgetTester tester,
    ControlledCustomerQueueRepository repository, {
    Size size = const Size(430, 1400),
    CustomerQueueRouteExpectation routeExpectation =
        CustomerQueueRouteExpectation.any,
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
        child: MaterialApp(
          home: CustomerQueueStatusScreen(
            restaurantBranchId: restaurantBranchId,
            queueEntryId: queueEntryId,
            routeExpectation: routeExpectation,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  final expectations = <QueueStatus, ({String key, String text})>{
    QueueStatus.waiting: (key: 'queue-status-waiting', text: 'Parties Ahead'),
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
      text: 'Meal Completed',
    ),
    QueueStatus.cancelled: (
      key: 'queue-status-cancelled',
      text: 'Queue Exited',
    ),
    QueueStatus.skipped: (
      key: 'queue-status-skipped',
      text: 'Queue Token Skipped',
    ),
    QueueStatus.noShow: (
      key: 'queue-status-no_show',
      text: 'Queue Token Closed',
    ),
    QueueStatus.expired: (
      key: 'queue-status-expired',
      text: 'Queue Token Expired',
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
      expect(find.textContaining('State Machine Restaurant'), findsWidgets);
      expect(find.textContaining('State Machine Branch'), findsWidgets);
      expect(
        find.byKey(const ValueKey('customer-identity-restaurant-name')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('customer-identity-branch-name')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('customer-identity-address')),
        findsOneWidget,
      );
      expect(find.text('Address unavailable'), findsOneWidget);
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
        expect(
          find.byKey(ValueKey('queue-status-icon-${status.wireName}')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('queue-status-browse-restaurants')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('queue-status-return-home')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('queue-status-view-menu')),
          status == QueueStatus.completed || status == QueueStatus.skipped
              ? findsOneWidget
              : findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('terminal states explain why the customer journey ended', (
    tester,
  ) async {
    final explanations = <QueueStatus, String>{
      QueueStatus.completed: 'Your meal is complete.',
      QueueStatus.cancelled: 'You chose to exit this queue.',
      QueueStatus.skipped: 'The restaurant skipped your token before seating.',
      QueueStatus.noShow:
          'The restaurant closed your token after your party did not arrive in time',
      QueueStatus.expired: 'This queue token is no longer active.',
    };

    for (final MapEntry(key: status, value: explanation)
        in explanations.entries) {
      final repository = ControlledCustomerQueueRepository(status);
      await pumpStatusScreen(tester, repository);

      expect(find.textContaining(explanation), findsOneWidget);
      expect(find.textContaining('State Machine Restaurant'), findsWidgets);
      expect(find.textContaining('State Machine Branch'), findsWidgets);
      await repository.close();
    }
  });

  testWidgets('ready and seated deep links enforce persisted queue status', (
    tester,
  ) async {
    var repository = ControlledCustomerQueueRepository(QueueStatus.waiting);
    await pumpStatusScreen(
      tester,
      repository,
      routeExpectation: CustomerQueueRouteExpectation.tableReady,
    );
    expect(find.byKey(const ValueKey('invalid-queue-link')), findsOneWidget);
    expect(find.text('Your table is ready!'), findsNothing);
    await repository.close();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    repository = ControlledCustomerQueueRepository(QueueStatus.reserved);
    await pumpStatusScreen(
      tester,
      repository,
      routeExpectation: CustomerQueueRouteExpectation.tableReady,
    );
    expect(find.text('Your table is ready!'), findsOneWidget);
    expect(find.text('F1-T4'), findsOneWidget);
    await repository.close();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    repository = ControlledCustomerQueueRepository(QueueStatus.seated);
    await pumpStatusScreen(
      tester,
      repository,
      routeExpectation: CustomerQueueRouteExpectation.seated,
    );
    expect(find.text('Enjoy your meal!'), findsOneWidget);
    expect(find.textContaining('F1-T4'), findsOneWidget);
    await repository.close();
  });

  testWidgets('waiting uses the shared Parties Ahead copy for every count', (
    tester,
  ) async {
    for (final (count, label) in <(int, String)>[
      (0, '0 Parties Ahead'),
      (1, '1 Party Ahead'),
      (2, '2 Parties Ahead'),
      (5, '5 Parties Ahead'),
    ]) {
      final repository = ControlledCustomerQueueRepository(
        QueueStatus.waiting,
        aheadCount: count,
      );
      await pumpStatusScreen(tester, repository);

      expect(find.text(label), findsOneWidget);
      expect(
        find.textContaining(RegExp('person|people', caseSensitive: false)),
        findsNothing,
      );
      await repository.close();
    }
  });

  testWidgets('waiting displays meaningful special notes as newline bullets', (
    tester,
  ) async {
    final repository = ControlledCustomerQueueRepository(
      QueueStatus.waiting,
      notes: 'Birthday celebration\n\n Allergic to peanuts ',
    );
    addTearDown(repository.close);

    await pumpStatusScreen(tester, repository);

    expect(
      find.byKey(const ValueKey('customer-special-notes')),
      findsOneWidget,
    );
    expect(find.text('Special Notes'), findsOneWidget);
    expect(find.text('Birthday celebration'), findsOneWidget);
    expect(find.text('Allergic to peanuts'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
  });

  testWidgets('waiting hides empty special notes', (tester) async {
    for (final notes in <String?>[null, '', '  \n  ']) {
      final repository = ControlledCustomerQueueRepository(
        QueueStatus.waiting,
        notes: notes,
      );
      await pumpStatusScreen(tester, repository);
      expect(
        find.byKey(const ValueKey('customer-special-notes')),
        findsNothing,
      );
      await repository.close();
    }
  });

  test('party-ahead copy uses correct singular and plural grammar', () {
    expect(partiesAheadLabel(0), '0 Parties Ahead');
    expect(partiesAheadLabel(1), '1 Party Ahead');
    expect(partiesAheadLabel(2), '2 Parties Ahead');
    expect(partiesAheadLabel(5), '5 Parties Ahead');
  });

  testWidgets('active visit card uses the shared Parties Ahead copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (count, label) in <(int, String)>[
      (1, '1 Party Ahead'),
      (2, '2 Parties Ahead'),
      (5, '5 Parties Ahead'),
    ]) {
      final repository = ControlledCustomerQueueRepository(
        QueueStatus.waiting,
        aheadCount: count,
        currentVisit: const CustomerQueueVisit(
          restaurantBranchId: restaurantBranchId,
          queueEntryId: queueEntryId,
          tokenCode: 'Q42',
          status: QueueStatus.waiting,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerQueueRepositoryProvider.overrideWithValue(repository),
            branchIdentityRepositoryProvider.overrideWithValue(
              PassthroughBranchIdentityRepository(),
            ),
            debugCustomerPhoneSessionProvider.overrideWithValue(
              ValueNotifier<String?>('+919999999999'),
            ),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(0.7)),
              child: CustomerAppHomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Parties Ahead'), findsOneWidget);
      expect(find.text(label), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await repository.close();
    }
  });

  testWidgets('exit queue confirmation uses standardized customer copy', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = ControlledCustomerQueueRepository(QueueStatus.waiting);
    addTearDown(repository.close);
    await pumpStatusScreen(tester, repository);

    expect(
      tester
          .getSemantics(
            find.descendant(
              of: find.byKey(const ValueKey('queue-status-cancel-action')),
              matching: find.byType(OutlinedButton),
            ),
          )
          .label,
      'Exit Queue',
    );
    semantics.dispose();
    await tester.tap(find.text('Exit Queue'));
    await tester.pump();

    expect(find.text('Exit Queue?'), findsOneWidget);
    expect(
      find.text(
        'You will lose your place in this queue. You can join again later.',
      ),
      findsOneWidget,
    );
    expect(find.text('Keep My Place'), findsOneWidget);
    expect(find.text('Exit Queue'), findsNWidgets(2));

    await tester.tap(find.text('Exit Queue').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('queue-status-cancelled')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('queue-status-waiting')), findsNothing);
    expect(find.text('You have exited the queue.'), findsOneWidget);
  });

  testWidgets('exit queue failure uses standardized customer copy', (
    tester,
  ) async {
    final repository = ControlledCustomerQueueRepository(
      QueueStatus.waiting,
      exitError: StateError('private backend detail'),
    );
    addTearDown(repository.close);
    await pumpStatusScreen(tester, repository);

    await tester.tap(find.text('Exit Queue'));
    await tester.pump();
    await tester.tap(find.text('Exit Queue').last);
    await tester.pump();

    expect(find.text('Could not exit the queue.'), findsOneWidget);
    expect(find.textContaining('private backend detail'), findsNothing);
    expect(find.text('Exit Queue'), findsOneWidget);
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
      initialLocation: '/customer/$restaurantBranchId/status/$queueEntryId',
      routes: [
        GoRoute(
          path: '/customer/:restaurantBranchId/status/:queueEntryId',
          builder: (context, state) => CustomerQueueStatusScreen(
            restaurantBranchId: state.pathParameters['restaurantBranchId']!,
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

  testWidgets('reopening reconstructs every persisted terminal status', (
    tester,
  ) async {
    final terminalStatuses = QueueStatus.values.where(
      (status) => status.isTerminal,
    );

    for (final status in terminalStatuses) {
      var repository = ControlledCustomerQueueRepository(status);
      await pumpStatusScreen(tester, repository);
      expect(
        find.byKey(ValueKey('queue-status-${status.wireName}')),
        findsOneWidget,
      );
      await repository.close();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository = ControlledCustomerQueueRepository(status);
      await pumpStatusScreen(tester, repository, size: const Size(390, 844));
      expect(
        find.byKey(ValueKey('queue-status-${status.wireName}')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('queue-status-waiting')), findsNothing);
      await repository.close();
    }
  });

  testWidgets('terminal actions navigate to their intended destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cases =
        <({QueueStatus status, String actionKey, String destinationText})>[
          (
            status: QueueStatus.expired,
            actionKey: 'queue-status-join-again',
            destinationText: 'join-destination:$restaurantBranchId',
          ),
          (
            status: QueueStatus.skipped,
            actionKey: 'queue-status-view-menu',
            destinationText:
                'menu-destination:$restaurantBranchId:$queueEntryId',
          ),
          (
            status: QueueStatus.noShow,
            actionKey: 'queue-status-browse-restaurants',
            destinationText: 'browse-destination',
          ),
          (
            status: QueueStatus.completed,
            actionKey: 'queue-status-return-home',
            destinationText: 'home-destination',
          ),
        ];

    for (final testCase in cases) {
      final repository = ControlledCustomerQueueRepository(testCase.status);
      final router = GoRouter(
        initialLocation: '/customer/$restaurantBranchId/status/$queueEntryId',
        routes: [
          GoRoute(
            path: '/customer/:restaurantBranchId/status/:queueEntryId',
            builder: (context, state) => CustomerQueueStatusScreen(
              restaurantBranchId: state.pathParameters['restaurantBranchId']!,
              queueEntryId: state.pathParameters['queueEntryId']!,
            ),
          ),
          GoRoute(
            path: '/customer/:restaurantBranchId',
            builder: (context, state) => Text(
              'join-destination:${state.pathParameters['restaurantBranchId']}',
            ),
          ),
          GoRoute(
            path: '/customer/:restaurantBranchId/menu',
            builder: (context, state) => Text(
              'menu-destination:'
              '${state.pathParameters['restaurantBranchId']}:'
              '${state.uri.queryParameters['queueEntryId']}',
            ),
          ),
          GoRoute(
            path: '/app/nearby',
            builder: (context, state) => const Text('browse-destination'),
          ),
          GoRoute(
            path: '/app/home',
            builder: (context, state) => const Text('home-destination'),
          ),
        ],
      );

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
      await tester.tap(find.byKey(ValueKey(testCase.actionKey)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(testCase.destinationText), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      router.dispose();
      await repository.close();
    }
  });

  testWidgets('Android back from queue status returns to customer home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = ControlledCustomerQueueRepository(QueueStatus.waiting);
    final router = GoRouter(
      initialLocation: '/customer/$restaurantBranchId/status/$queueEntryId',
      routes: [
        GoRoute(
          path: '/customer/:restaurantBranchId/status/:queueEntryId',
          builder: (context, state) => CustomerQueueStatusScreen(
            restaurantBranchId: state.pathParameters['restaurantBranchId']!,
            queueEntryId: state.pathParameters['queueEntryId']!,
          ),
        ),
        GoRoute(
          path: '/app/home',
          builder: (context, state) => const Text('authenticated-home'),
        ),
      ],
    );

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
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('authenticated-home'), findsOneWidget);
    router.dispose();
    await repository.close();
  });

  testWidgets('missing or malformed queue links render invalid-link UI', (
    tester,
  ) async {
    final repository = ControlledCustomerQueueRepository(
      QueueStatus.waiting,
      streamError: const FormatException('Unknown queue status "mystery".'),
    );
    addTearDown(repository.close);

    await pumpStatusScreen(tester, repository);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('invalid-queue-link')), findsOneWidget);
    expect(find.textContaining('Unknown queue status'), findsOneWidget);
    expect(find.byKey(const ValueKey('queue-status-waiting')), findsNothing);
  });
}

class ControlledCustomerQueueRepository implements CustomerQueueRepository {
  ControlledCustomerQueueRepository(
    QueueStatus initialStatus, {
    this.streamError,
    this.exitError,
    this.aheadCount = 2,
    this.currentVisit,
    String? notes,
  }) : _entry = _entryFor(initialStatus, notes: notes);

  final Object? streamError;
  final Object? exitError;
  final int aheadCount;
  final CustomerQueueVisit? currentVisit;
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
    required String restaurantBranchId,
    required String queueEntryId,
    required String phone,
  }) async {
    final error = exitError;
    if (error != null) throw error;
    if (!_entry.status.canBeCancelledByCustomer) {
      throw StateError('Cancellation is not permitted.');
    }
    emitStatus(QueueStatus.cancelled);
  }

  @override
  Future<void> extendHold({
    required String restaurantBranchId,
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
    return currentVisit;
  }

  @override
  Future<JoinQueueResult> joinQueue(JoinQueueRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<void> markOnTheWay({
    required String restaurantBranchId,
    required String queueEntryId,
    required String phone,
  }) async {
    emitStatus(QueueStatus.onTheWay);
  }

  @override
  Future<bool> validateAssignedTables({
    required String restaurantBranchId,
    required QueueEntry entry,
  }) async {
    return restaurantBranchId ==
            'state-machine-restaurant-state-machine-branch' &&
        entry.id == 'state-machine-entry' &&
        entry.assignedTableId == 'table-4';
  }

  @override
  Stream<CustomerQueueState> watchQueueState({
    required String restaurantBranchId,
    required String queueEntryId,
  }) async* {
    final error = streamError;
    if (error != null) throw error;
    yield CustomerQueueState(entry: _entry, partiesAhead: aheadCount);
    await for (final entry in _controller.stream) {
      yield CustomerQueueState(entry: entry, partiesAhead: aheadCount);
    }
  }

  @override
  Stream<QueueEntry> watchQueueEntry({
    required String restaurantBranchId,
    required String queueEntryId,
  }) async* {
    final error = streamError;
    if (error != null) throw error;
    yield _entry;
    yield* _controller.stream;
  }

  static QueueEntry _entryFor(QueueStatus status, {String? notes}) {
    return QueueEntry(
      id: 'state-machine-entry',
      tokenNumber: 42,
      tokenCode: 'Q42',
      businessDate: '2026-07-29',
      customerName: 'State Machine Customer',
      phone: '+919999999999',
      partySize: 4,
      partySizeBand: '3-4',
      notes: notes,
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
