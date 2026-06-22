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
    this.currentQueueEntryId,
    this.currentTokenCode,
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
  final String? currentQueueEntryId;
  final String? currentTokenCode;
  final int sortOrder;
  final DateTime? reservedAt;
  final DateTime? occupiedAt;
  final DateTime? cleaningStartedAt;
  final DateTime? lastCompletedAt;
  final DateTime? currentCycleStartAt;
  final DateTime? lastCycleStartAt;
  final DateTime? lastCycleEndAt;

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
      currentQueueEntryId: data['currentQueueEntryId'] as String?,
      currentTokenCode: data['currentTokenCode'] as String?,
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
    'currentQueueEntryId': currentQueueEntryId,
    'currentTokenCode': currentTokenCode,
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
