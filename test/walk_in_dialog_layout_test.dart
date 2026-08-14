import 'dart:async';

import 'package:ezq/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:ezq/features/queue/data/queue_repository.dart';
import 'package:ezq/features/queue/domain/queue_entry.dart';
import 'package:ezq/features/tables/data/table_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('normal desktop height displays the complete dialog', (
    tester,
  ) async {
    final repository = _RecordingQueueRepository();
    await _pumpDashboard(tester, const Size(1440, 900), repository);
    await _openWalkIn(tester);

    expect(find.text('Add walk-in'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Add to queue'), findsOneWidget);
    expect(tester.takeException(), isNull);
    _expectBodyEndsBeforeActions(tester);
  });

  for (final viewport in [
    const Size(1440, 400),
    const Size(1024, 500),
    const Size(844, 390),
    const Size(390, 844),
  ]) {
    testWidgets(
      'bounded ${viewport.width}x${viewport.height} layout keeps actions separate',
      (tester) async {
        final repository = _RecordingQueueRepository();
        await _pumpDashboard(tester, viewport, repository);
        await _openWalkIn(tester);

        _expectBodyEndsBeforeActions(tester);
        await tester.drag(
          find.byKey(const ValueKey('add-walk-in-form-scroll')),
          const Offset(0, -1000),
        );
        await tester.pumpAndSettle();

        expect(find.text('Special Notes (Optional)'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Add to queue'), findsOneWidget);
        expect(tester.takeException(), isNull);
        _expectBodyEndsBeforeActions(tester);
      },
    );
  }

  testWidgets('keyboard inset shrinks the form body but not the action area', (
    tester,
  ) async {
    final repository = _RecordingQueueRepository();
    await _pumpDashboard(tester, const Size(1024, 768), repository);
    await _openWalkIn(tester);
    final bodyBefore = tester.getSize(
      find.byKey(const ValueKey('add-walk-in-form-scroll')),
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final bodyAfter = tester.getSize(
      find.byKey(const ValueKey('add-walk-in-form-scroll')),
    );
    expect(bodyAfter.height, lessThan(bodyBefore.height));
    _expectBodyEndsBeforeActions(tester);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Add to queue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validation and duplicate submission guard remain intact', (
    tester,
  ) async {
    final repository = _RecordingQueueRepository(blockSubmission: true);
    await _pumpDashboard(tester, const Size(1024, 500), repository);
    await _openWalkIn(tester);

    await tester.tap(find.text('Add to queue'));
    await tester.pump();
    expect(find.text('Enter guest name'), findsWidgets);
    expect(repository.addCount, 0);

    await tester.enterText(find.byType(TextFormField).first, 'Layout Test');
    await tester.tap(find.text('Add to queue'));
    await tester.tap(find.text('Add to queue'));
    await tester.pump();
    expect(repository.addCount, 1);

    repository.completeSubmission();
    await tester.pumpAndSettle();
    expect(repository.addCount, 1);
    expect(find.text('Add walk-in'), findsNothing);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  Size size,
  QueueRepository repository,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        queueRepositoryProvider.overrideWithValue(repository),
        tableRepositoryProvider.overrideWithValue(MockTableRepository()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => const AdminWalkInDialog(
                  restaurantId: 'test-restaurant',
                  branchId: 'test-branch',
                ),
              ),
              child: const Text('Open walk-in'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _openWalkIn(WidgetTester tester) async {
  await tester.tap(find.text('Open walk-in'));
  await tester.pumpAndSettle();
}

void _expectBodyEndsBeforeActions(WidgetTester tester) {
  final body = tester.getRect(
    find.byKey(const ValueKey('add-walk-in-form-scroll')),
  );
  final actions = tester.getRect(
    find.byKey(const ValueKey('add-walk-in-actions')),
  );
  expect(body.bottom, lessThanOrEqualTo(actions.top));
}

class _RecordingQueueRepository implements QueueRepository {
  _RecordingQueueRepository({this.blockSubmission = false});

  final bool blockSubmission;
  final Completer<void> _submissionGate = Completer<void>();
  int addCount = 0;

  void completeSubmission() {
    if (!_submissionGate.isCompleted) _submissionGate.complete();
  }

  @override
  Future<AddWalkInResult> addWalkIn(AddWalkInRequest request) async {
    addCount++;
    if (blockSubmission) await _submissionGate.future;
    return const AddWalkInResult(
      queueEntryId: 'walk-in-test',
      tokenNumber: 1,
      tokenCode: 'Q01',
    );
  }

  @override
  Future<void> markNoShow({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  }) async {}

  @override
  Future<void> skipCustomer({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  }) async {}

  @override
  Stream<List<QueueEntry>> watchTodayQueue({
    required String restaurantId,
    required String branchId,
  }) => Stream.value(const []);
}
