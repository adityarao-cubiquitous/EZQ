import 'package:ezq/features/tables/data/table_repository.dart';
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
}
