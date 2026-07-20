import 'package:ezq/features/recommendation/domain/multi_table_recommendation.dart';
import 'package:ezq/features/tables/domain/restaurant_table.dart';
import 'package:ezq/features/tables/domain/table_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'does not recommend multiple tables when one available table can fit',
    () {
      final result = recommendMultiTableCombination(
        partySize: 6,
        tables: [
          _table('T2', capacity: 2),
          _table('T4', capacity: 4),
          _table('T6', capacity: 6),
        ],
      );

      expect(result.isEmpty, isTrue);
    },
  );

  test(
    'recommends exact best fit and higher-capacity next best on one floor',
    () {
      final result = recommendMultiTableCombination(
        partySize: 10,
        tables: [
          _table('T2', capacity: 2),
          _table('T4', capacity: 4),
          _table('T6A', capacity: 6),
          _table('T6B', capacity: 6),
        ],
      );

      expect(result.bestFits.map(_ids), [
        ['T4', 'T6A'],
        ['T4', 'T6B'],
      ]);
      expect(result.bestFits.map((fit) => fit.totalCapacity), [10, 10]);
      expect(result.nextBestFits.map(_ids), [
        ['T6A', 'T6B'],
      ]);
      expect(result.nextBestFits.single.totalCapacity, 12);
    },
  );

  test('never combines tables from different floors', () {
    final result = recommendMultiTableCombination(
      partySize: 10,
      tables: [
        _table('G6', capacity: 6, floorId: 'ground'),
        _table('F4', capacity: 4, floorId: 'first'),
      ],
    );

    expect(result.isEmpty, isTrue);
  });

  test(
    'uses only available tables when finding the maximum and combinations',
    () {
      final result = recommendMultiTableCombination(
        partySize: 10,
        tables: [
          _table('T12', capacity: 12, status: TableStatus.occupied),
          _table('T4', capacity: 4),
          _table('T6', capacity: 6),
        ],
      );

      expect(result.bestFits.map(_ids), [
        ['T4', 'T6'],
      ]);
      expect(result.nextBestFits, isEmpty);
    },
  );

  test('prioritizes the least number of tables for next best fit', () {
    final result = recommendMultiTableCombination(
      partySize: 10,
      tables: [
        _table('T4A', capacity: 4),
        _table('T4B', capacity: 4),
        _table('T4C', capacity: 4),
        _table('T6A', capacity: 6),
        _table('T6B', capacity: 6),
      ],
    );

    expect(result.nextBestFits.single.tables.length, 2);
    expect(_ids(result.nextBestFits.single), ['T6A', 'T6B']);
  });

  test('returns every minimum-table exact fit on every floor', () {
    final result = recommendMultiTableCombination(
      partySize: 10,
      tables: [
        _table('G4', capacity: 4, floorId: 'ground'),
        _table('G6', capacity: 6, floorId: 'ground'),
        _table('F2', capacity: 2, floorId: 'first'),
        _table('F8', capacity: 8, floorId: 'first'),
      ],
    );

    expect(result.bestFits.map(_ids), [
      ['F2', 'F8'],
      ['G4', 'G6'],
    ]);
  });

  test('returns all higher-capacity combinations at the minimum count', () {
    final result = recommendMultiTableCombination(
      partySize: 10,
      tables: [
        _table('T4', capacity: 4),
        _table('T6', capacity: 6),
        _table('T7', capacity: 7),
        _table('T8', capacity: 8),
      ],
    );

    expect(result.nextBestFits.map(_ids), [
      ['T4', 'T7'],
      ['T4', 'T8'],
      ['T6', 'T7'],
      ['T6', 'T8'],
      ['T7', 'T8'],
    ]);
  });

  test('excludes partially occupied tables from combinations', () {
    final result = recommendMultiTableCombination(
      partySize: 10,
      tables: [
        _table('T6', capacity: 6),
        _table('T8', capacity: 8, status: TableStatus.occupied),
      ],
      openSeatsFor: (table) => table.id == 'T8' ? 4 : table.capacity,
    );

    expect(result.isEmpty, isTrue);
  });

  test('does not recommend combinations requiring three tables', () {
    final result = recommendMultiTableCombination(
      partySize: 10,
      tables: [
        _table('T3A', capacity: 3),
        _table('T3B', capacity: 3),
        _table('T4', capacity: 4),
      ],
    );

    expect(result.isEmpty, isTrue);
  });
}

List<String> _ids(TableCombinationRecommendation recommendation) =>
    recommendation.tables.map((table) => table.id).toList();

RestaurantTable _table(
  String id, {
  required int capacity,
  String floorId = 'ground',
  TableStatus status = TableStatus.available,
}) {
  return RestaurantTable(
    id: id,
    tableNumber: id,
    displayTableName: id,
    capacity: capacity,
    tableType: '$capacity-top',
    section: 'main',
    floorId: floorId,
    status: status,
    sortOrder: 0,
  );
}
