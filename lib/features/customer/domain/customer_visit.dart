class CustomerVisit {
  const CustomerVisit({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    required this.queueEntryId,
    required this.businessDate,
    required this.partySize,
    required this.status,
    required this.waitMinutes,
    required this.joinedAt,
    this.seatedAt,
  });

  final String id;
  final String restaurantId;
  final String branchId;
  final String queueEntryId;
  final String businessDate;
  final int partySize;
  final String status;
  final int waitMinutes;
  final DateTime joinedAt;
  final DateTime? seatedAt;
}
