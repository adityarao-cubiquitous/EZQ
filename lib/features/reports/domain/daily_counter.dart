class DailyCounter {
  const DailyCounter({
    required this.businessDate,
    required this.lastTokenNumber,
    required this.totalJoined,
    required this.totalSeated,
    required this.totalSkipped,
    required this.totalCancelled,
    required this.totalNoShow,
    required this.peakQueueDepth,
  });

  final String businessDate;
  final int lastTokenNumber;
  final int totalJoined;
  final int totalSeated;
  final int totalSkipped;
  final int totalCancelled;
  final int totalNoShow;
  final int peakQueueDepth;

  factory DailyCounter.fromMap(Map<String, dynamic> data) {
    return DailyCounter(
      businessDate: data['businessDate'] as String? ?? '',
      lastTokenNumber: data['lastTokenNumber'] as int? ?? 0,
      totalJoined: data['totalJoined'] as int? ?? 0,
      totalSeated: data['totalSeated'] as int? ?? 0,
      totalSkipped: data['totalSkipped'] as int? ?? 0,
      totalCancelled: data['totalCancelled'] as int? ?? 0,
      totalNoShow: data['totalNoShow'] as int? ?? 0,
      peakQueueDepth: data['peakQueueDepth'] as int? ?? 0,
    );
  }
}
