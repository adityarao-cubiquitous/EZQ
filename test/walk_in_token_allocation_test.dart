import 'package:ezq/features/queue/data/queue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalkInTokenAllocation', () {
    test('normal submission allocates exactly one next token', () {
      final allocation = WalkInTokenAllocation.resolve(
        existingQueueEntry: null,
        lastTokenNumber: 7,
      );

      expect(allocation.shouldAllocate, isTrue);
      expect(allocation.tokenNumber, 8);
      expect(allocation.tokenCode, 'Q08');
    });

    test('transaction re-execution reuses the same submission token', () {
      var counter = 7;
      var tokenAllocations = 0;
      final queueEntries = <String, Map<String, dynamic>>{};
      const queueEntryId = 'stable-request-id';

      WalkInTokenAllocation executeTransactionAttempt() {
        final allocation = WalkInTokenAllocation.resolve(
          existingQueueEntry: queueEntries[queueEntryId],
          lastTokenNumber: counter,
        );
        if (allocation.shouldAllocate) {
          counter = allocation.tokenNumber;
          tokenAllocations += 1;
          queueEntries[queueEntryId] = {
            'tokenNumber': allocation.tokenNumber,
            'tokenCode': allocation.tokenCode,
          };
        }
        return allocation;
      }

      final firstAttempt = executeTransactionAttempt();
      final retry = executeTransactionAttempt();

      expect(firstAttempt.tokenCode, 'Q08');
      expect(retry.shouldAllocate, isFalse);
      expect(retry.tokenCode, 'Q08');
      expect(queueEntries, hasLength(1));
      expect(counter, 8);
      expect(tokenAllocations, 1);
    });
  });
}
