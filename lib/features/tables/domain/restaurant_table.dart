import 'table_status.dart';

class RestaurantTable {
  const RestaurantTable({
    required this.id,
    required this.tableNumber,
    required this.capacity,
    required this.tableType,
    required this.section,
    required this.status,
    required this.sortOrder,
    this.occupancy = 0,
    this.adjacentTableIds = const [],
    this.currentQueueEntryId,
    this.currentTokenCode,
    this.currentPartySize,
    this.reservedAt,
    this.occupiedAt,
    this.cleaningStartedAt,
    this.lastCompletedAt,
    this.currentCycleStartAt,
    this.lastCycleStartAt,
    this.lastCycleEndAt,
  });

  final String id;
  final String tableNumber;
  final int capacity;
  final String tableType;
  final String section;
  final TableStatus status;
  final int occupancy;
  final List<String> adjacentTableIds;
  final String? currentQueueEntryId;
  final String? currentTokenCode;
  final int? currentPartySize;
  final int sortOrder;
  final DateTime? reservedAt;
  final DateTime? occupiedAt;
  final DateTime? cleaningStartedAt;
  final DateTime? lastCompletedAt;
  final DateTime? currentCycleStartAt;
  final DateTime? lastCycleStartAt;
  final DateTime? lastCycleEndAt;

  int get remainingSeats => capacity - occupancy;

  bool get isPartiallyOccupied =>
      status == TableStatus.occupied && occupancy > 0 && occupancy < capacity;

  factory RestaurantTable.fromMap(String id, Map<String, dynamic> data) {
    DateTime? readDate(String key) {
      final value = data[key];
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value != null && value.runtimeType.toString() == 'Timestamp') {
        return (value as dynamic).toDate() as DateTime;
      }
      return null;
    }

    return RestaurantTable(
      id: id,
      tableNumber: data['tableNumber'] as String? ?? '',
      capacity: data['capacity'] as int? ?? 2,
      tableType: data['tableType'] as String? ?? '2-top',
      section: data['section'] as String? ?? 'main',
      status: TableStatus.fromWireName(data['status'] as String?),
      occupancy: data['occupancy'] as int? ?? 0,
      adjacentTableIds:
          (data['adjacentTableIds'] as List<dynamic>?)?.cast<String>() ??
              const [],
      currentQueueEntryId: data['currentQueueEntryId'] as String?,
      currentTokenCode: data['currentTokenCode'] as String?,
      currentPartySize: data['currentPartySize'] as int?,
      sortOrder: data['sortOrder'] as int? ?? 0,
      reservedAt: readDate('reservedAt'),
      occupiedAt: readDate('occupiedAt'),
      cleaningStartedAt: readDate('cleaningStartedAt'),
      lastCompletedAt: readDate('lastCompletedAt'),
      currentCycleStartAt: readDate('currentCycleStartAt'),
      lastCycleStartAt: readDate('lastCycleStartAt'),
      lastCycleEndAt: readDate('lastCycleEndAt'),
    );
  }

  Map<String, dynamic> toMap() => {
    'tableNumber': tableNumber,
    'capacity': capacity,
    'tableType': tableType,
    'section': section,
    'status': status.wireName,
    'occupancy': occupancy,
    'adjacentTableIds': adjacentTableIds,
    'currentQueueEntryId': currentQueueEntryId,
    'currentTokenCode': currentTokenCode,
    'currentPartySize': currentPartySize,
    'sortOrder': sortOrder,
    'reservedAt': reservedAt?.toIso8601String(),
    'occupiedAt': occupiedAt?.toIso8601String(),
    'cleaningStartedAt': cleaningStartedAt?.toIso8601String(),
    'lastCompletedAt': lastCompletedAt?.toIso8601String(),
    'currentCycleStartAt': currentCycleStartAt?.toIso8601String(),
    'lastCycleStartAt': lastCycleStartAt?.toIso8601String(),
    'lastCycleEndAt': lastCycleEndAt?.toIso8601String(),
  };
}
