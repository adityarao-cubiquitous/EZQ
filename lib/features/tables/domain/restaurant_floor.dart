class RestaurantFloor {
  const RestaurantFloor({
    required this.id,
    required this.floorId,
    required this.floorName,
    required this.displayOrder,
    required this.tableCount,
    required this.seatCount,
  });

  final String id;
  final String floorId;
  final String floorName;
  final int displayOrder;
  final int tableCount;
  final int seatCount;

  factory RestaurantFloor.fromMap(String id, Map<String, dynamic> data) {
    final floorId = (data['floorId'] as String? ?? id).trim();
    return RestaurantFloor(
      id: id,
      floorId: floorId.isEmpty ? id : floorId,
      floorName: (data['floorName'] as String? ?? floorId).trim(),
      displayOrder: data['displayOrder'] as int? ?? 0,
      tableCount: data['tableCount'] as int? ?? 0,
      seatCount: data['seatCount'] as int? ?? 0,
    );
  }
}
