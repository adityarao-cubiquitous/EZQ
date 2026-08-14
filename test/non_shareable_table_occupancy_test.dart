import 'package:ezq/features/tables/data/table_repository.dart';
import 'package:ezq/features/recommendation/domain/recommendation_types.dart';
import 'package:ezq/features/tables/domain/table_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('occupiedSeatCountForSeatedEntry', () {
    test('marks an empty-table-only party as consuming the full table', () {
      final occupiedSeats = occupiedSeatCountForSeatedEntry(
        tableCapacity: 4,
        partySize: 2,
        customerPreferences: const {'seatingPreference': 'EMPTY_TABLE_ONLY'},
      );

      expect(occupiedSeats, 4);
    });

    test('keeps shared seating occupancy as the actual party size', () {
      final occupiedSeats = occupiedSeatCountForSeatedEntry(
        tableCapacity: 4,
        partySize: 2,
        customerPreferences: const {'seatingPreference': 'ANY_AVAILABLE'},
      );

      expect(occupiedSeats, 2);
    });
  });

  group('canSeatWaitingPartyAtTable', () {
    test('allows the exact partial-table defect scenario', () {
      expect(
        canSeatWaitingPartyAtTable(
          status: TableStatus.occupied,
          tableCapacity: 4,
          occupiedSeats: 3,
          partySize: 1,
          seatingPreference: SeatingPreference.anyAvailable,
        ),
        isTrue,
      );
    });

    test('rejects full, ineligible, and non-sharing occupied tables', () {
      expect(
        canSeatWaitingPartyAtTable(
          status: TableStatus.occupied,
          tableCapacity: 4,
          occupiedSeats: 4,
          partySize: 1,
          seatingPreference: SeatingPreference.anyAvailable,
        ),
        isFalse,
      );
      expect(
        canSeatWaitingPartyAtTable(
          status: TableStatus.blocked,
          tableCapacity: 4,
          occupiedSeats: 0,
          partySize: 1,
          seatingPreference: SeatingPreference.anyAvailable,
        ),
        isFalse,
      );
      expect(
        canSeatWaitingPartyAtTable(
          status: TableStatus.occupied,
          tableCapacity: 4,
          occupiedSeats: 2,
          partySize: 2,
          seatingPreference: SeatingPreference.emptyTableOnly,
        ),
        isFalse,
      );
    });

    test('supports larger parties without changing multi-table rules', () {
      expect(
        canSeatWaitingPartyAtTable(
          status: TableStatus.occupied,
          tableCapacity: 6,
          occupiedSeats: 2,
          partySize: 4,
          seatingPreference: SeatingPreference.anyAvailable,
        ),
        isTrue,
      );
      expect(
        canSeatWaitingPartyAtTable(
          status: TableStatus.occupied,
          tableCapacity: 6,
          occupiedSeats: 2,
          partySize: 4,
          seatingPreference: SeatingPreference.anyAvailable,
          selectedTableCount: 2,
        ),
        isFalse,
      );
    });
  });
}
