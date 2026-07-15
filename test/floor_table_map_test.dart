import 'package:ezq/features/tables/domain/floor_table_map.dart';
import 'package:ezq/features/tables/domain/restaurant_floor.dart';
import 'package:ezq/features/tables/domain/restaurant_table.dart';
import 'package:ezq/features/tables/domain/table_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'capacity floor sections preserve floor order and numeric table order',
    () {
      final floorOne = _floor('F1', 'Floor 1', 1);
      final floorTwo = _floor('F2', 'Floor 2', 2);
      final map = RestaurantFloorTableMap(
        sections: [
          RestaurantFloorTableSection(
            floor: floorOne,
            tables: [
              _table('table-10', 'T10', floorOne.floorId),
              _table('table-2', 'T2', floorOne.floorId),
              _table('table-1', 'T1', floorOne.floorId),
            ],
          ),
          RestaurantFloorTableSection(
            floor: floorTwo,
            tables: [_table('table-11', 'T11', floorTwo.floorId)],
          ),
        ],
      );

      final section = map.capacityFloorSections.single;

      expect(section.floors.map((section) => section.floor.floorId), [
        'F1',
        'F2',
      ]);
      expect(
        section.floors.first.tables.map((table) => table.displayTableName),
        ['F1-T1', 'F1-T2', 'F1-T10'],
      );
    },
  );
}

RestaurantFloor _floor(String floorId, String floorName, int displayOrder) {
  return RestaurantFloor(
    id: floorId,
    floorId: floorId,
    floorName: floorName,
    displayOrder: displayOrder,
    tableCount: 0,
    seatCount: 0,
  );
}

RestaurantTable _table(String id, String tableNumber, String floorId) {
  return RestaurantTable(
    id: id,
    tableNumber: tableNumber,
    displayTableName: '$floorId-$tableNumber',
    floorId: floorId,
    capacity: 4,
    tableType: '4-top',
    section: 'main',
    status: TableStatus.available,
    sortOrder: 0,
    updatedAt: DateTime(2026),
  );
}
