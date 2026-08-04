import 'package:ezq/features/tables/domain/floor_table_map.dart';
import 'package:ezq/features/tables/domain/restaurant_floor.dart';
import 'package:ezq/features/tables/domain/restaurant_table.dart';
import 'package:ezq/features/tables/domain/table_status.dart';
import 'package:ezq/features/tables/presentation/table_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('table title and status legend do not overflow narrow panels', (
    tester,
  ) async {
    const floor = RestaurantFloor(
      id: 'F1',
      floorId: 'F1',
      floorName: 'Floor 1',
      displayOrder: 1,
      tableCount: 1,
      seatCount: 2,
    );
    const table = RestaurantTable(
      id: 'F1-T1',
      tableNumber: 'F1-T1',
      displayTableName: 'F1-T1',
      capacity: 2,
      tableType: '2-top',
      section: 'main',
      floorId: 'F1',
      status: TableStatus.available,
      sortOrder: 1,
    );
    const floorTableMap = RestaurantFloorTableMap(
      sections: [
        RestaurantFloorTableSection(floor: floor, tables: [table]),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 221,
              child: TableGrid(floorTableMap: floorTableMap),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
  });
}
