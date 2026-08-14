import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/queue/domain/queue_status.dart';
import 'package:ezq/features/tables/data/table_repository.dart';

void main() {
  group('meal completion queue action', () {
    test('seated entries complete normally', () {
      expect(
        mealCompletionQueueAction(QueueStatus.seated),
        MealCompletionQueueAction.complete,
      );
    });

    test(
      'recorded F1-T7 cancelled entry is preserved while tables release',
      () {
        expect(
          mealCompletionQueueAction(QueueStatus.cancelled),
          MealCompletionQueueAction.preserveTerminal,
        );
      },
    );

    test(
      'already available queue states keep existing transition behavior',
      () {
        expect(
          () => mealCompletionQueueAction(QueueStatus.waiting),
          throwsStateError,
        );
      },
    );
  });

  group('completed table update', () {
    for (final capacity in [2, 4, 6]) {
      test(
        'occupied $capacity-top becomes available and clears assignment',
        () {
          final timestamp = DateTime(2026, 8, 14, 18);
          final cycleStart = timestamp.subtract(const Duration(minutes: 40));
          final update = completedTableUpdate(
            queueEntryId: 'queue-$capacity',
            completedPartySize: capacity,
            completionTimestamp: timestamp,
            cycleStartAt: cycleStart,
          );

          expect(update['status'], 'available');
          expect(update['currentQueueEntryId'], isNull);
          expect(update['currentTokenCode'], isNull);
          expect(update['currentPartySize'], isNull);
          expect(update['reservedAt'], isNull);
          expect(update['occupiedAt'], isNull);
          expect(update['currentCycleStartAt'], isNull);
          expect(update['lastCompletedQueueEntryId'], 'queue-$capacity');
          expect(update['lastCompletedPartySize'], capacity);
          expect(update['lastCycleStartAt'], cycleStart);
          expect(update['lastCycleEndAt'], timestamp);
        },
      );
    }

    test('cleanup does not overwrite permanent table configuration', () {
      final update = completedTableUpdate(
        queueEntryId: 'q8',
        completedPartySize: 4,
        completionTimestamp: DateTime(2026, 8, 14, 18),
        cycleStartAt: DateTime(2026, 8, 14, 17),
      );

      expect(
        update.keys,
        isNot(containsAll(['tableNumber', 'capacity', 'floorId', 'sortOrder'])),
      );
    });
  });

  test('repeated confirmation recognizes an already completed assignment', () {
    expect(
      isIdempotentMealCompletion(
        tableData: {
          'status': 'available',
          'currentQueueEntryId': null,
          'lastCompletedQueueEntryId': 'q8',
        },
        queueEntryId: 'q8',
      ),
      isTrue,
    );
  });
}
