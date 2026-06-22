enum QueueStatus {
  waiting,
  reserved,
  onTheWay,
  seated,
  completed,
  skipped,
  cancelled,
  noShow;

  String get wireName => switch (this) {
    QueueStatus.waiting => 'waiting',
    QueueStatus.reserved => 'reserved',
    QueueStatus.onTheWay => 'on_the_way',
    QueueStatus.seated => 'seated',
    QueueStatus.completed => 'completed',
    QueueStatus.skipped => 'skipped',
    QueueStatus.cancelled => 'cancelled',
    QueueStatus.noShow => 'no_show',
  };

  static QueueStatus fromWireName(String? value) {
    return QueueStatus.values.firstWhere(
      (status) => status.wireName == value,
      orElse: () => QueueStatus.waiting,
    );
  }

  bool canTransitionTo(QueueStatus next) {
    return switch (this) {
      QueueStatus.waiting => {
        QueueStatus.reserved,
        QueueStatus.skipped,
        QueueStatus.cancelled,
      }.contains(next),
      QueueStatus.reserved => {
        QueueStatus.onTheWay,
        QueueStatus.seated,
        QueueStatus.noShow,
        QueueStatus.cancelled,
      }.contains(next),
      QueueStatus.onTheWay => {
        QueueStatus.seated,
        QueueStatus.noShow,
        QueueStatus.cancelled,
      }.contains(next),
      QueueStatus.seated => next == QueueStatus.completed,
      QueueStatus.completed ||
      QueueStatus.skipped ||
      QueueStatus.cancelled ||
      QueueStatus.noShow => false,
    };
  }

  bool get isLiveQueueVisible => switch (this) {
    QueueStatus.waiting || QueueStatus.reserved || QueueStatus.onTheWay => true,
    QueueStatus.seated ||
    QueueStatus.completed ||
    QueueStatus.skipped ||
    QueueStatus.cancelled ||
    QueueStatus.noShow => false,
  };
}
