import 'restaurant_floor.dart';
import 'restaurant_table.dart';

class RestaurantFloorTableMap {
  const RestaurantFloorTableMap({required this.sections});

  static const empty = RestaurantFloorTableMap(sections: []);

  final List<RestaurantFloorTableSection> sections;

  List<RestaurantTable> get tables => [
    for (final section in sections) ...section.tables,
  ];

  List<RestaurantCapacityTableGroup> get capacityGroups {
    final groupsByCapacity = <int, List<RestaurantTable>>{};
    for (final table in tables) {
      groupsByCapacity.putIfAbsent(table.capacity, () => []).add(table);
    }

    final capacities = groupsByCapacity.keys.toList()..sort();
    return [
      for (final capacity in capacities)
        RestaurantCapacityTableGroup(
          capacity: capacity,
          capacityLabel: _capacityLabelFor(
            groupsByCapacity[capacity]!,
            capacity,
          ),
          tables: groupsByCapacity[capacity]!..sort(_compareTablesForDisplay),
        ),
    ];
  }

  List<RestaurantCapacityFloorTableSection> get capacityFloorSections {
    final capacities = tables.map((table) => table.capacity).toSet().toList()
      ..sort();

    return [
      for (final capacity in capacities)
        RestaurantCapacityFloorTableSection(
          capacity: capacity,
          capacityLabel: _capacityLabelFor(
            tables.where((table) => table.capacity == capacity),
            capacity,
          ),
          floors: [
            for (final section in sections)
              RestaurantFloorTableSection(
                floor: section.floor,
                tables:
                    section.tables
                        .where((table) => table.capacity == capacity)
                        .toList()
                      ..sort(_compareTablesForDisplay),
              ),
          ],
        ),
    ];
  }
}

class RestaurantFloorTableSection {
  const RestaurantFloorTableSection({
    required this.floor,
    required this.tables,
  });

  final RestaurantFloor floor;
  final List<RestaurantTable> tables;

  List<RestaurantCapacityTableGroup> get capacityGroups {
    final groupsByCapacity = <int, List<RestaurantTable>>{};
    for (final table in tables) {
      groupsByCapacity.putIfAbsent(table.capacity, () => []).add(table);
    }

    final capacities = groupsByCapacity.keys.toList()..sort();
    return [
      for (final capacity in capacities)
        RestaurantCapacityTableGroup(
          capacity: capacity,
          capacityLabel: _capacityLabelFor(
            groupsByCapacity[capacity]!,
            capacity,
          ),
          tables: groupsByCapacity[capacity]!..sort(_compareTablesForDisplay),
        ),
    ];
  }
}

class RestaurantCapacityTableGroup {
  const RestaurantCapacityTableGroup({
    required this.capacity,
    required this.capacityLabel,
    required this.tables,
  });

  final int capacity;
  final String capacityLabel;
  final List<RestaurantTable> tables;
}

class RestaurantCapacityFloorTableSection {
  const RestaurantCapacityFloorTableSection({
    required this.capacity,
    required this.capacityLabel,
    required this.floors,
  });

  final int capacity;
  final String capacityLabel;
  final List<RestaurantFloorTableSection> floors;

  int get tableCount =>
      floors.fold<int>(0, (total, section) => total + section.tables.length);
}

int _compareTablesForDisplay(RestaurantTable a, RestaurantTable b) {
  final sortOrder = a.sortOrder.compareTo(b.sortOrder);
  if (sortOrder != 0) return sortOrder;
  return _compareTableNumbers(a.tableNumber, b.tableNumber);
}

String _capacityLabelFor(Iterable<RestaurantTable> tables, int capacity) {
  for (final table in tables) {
    final label = table.tableType.trim();
    if (label.isNotEmpty) return label;
  }
  return capacity.toString();
}

int _compareTableNumbers(String a, String b) {
  final aNumber = _trailingNumber(a);
  final bNumber = _trailingNumber(b);
  if (aNumber != null && bNumber != null && aNumber != bNumber) {
    return aNumber.compareTo(bNumber);
  }
  return a.compareTo(b);
}

int? _trailingNumber(String value) {
  final match = RegExp(r'(\d+)$').firstMatch(value.trim());
  return match == null ? null : int.tryParse(match.group(1)!);
}
