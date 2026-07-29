enum QueueStatus {
  waiting,
  reserved,
  onTheWay,
  seated,
  completed,
  skipped,
  cancelled,
  noShow,
  expired;

  String get wireName => switch (this) {
    QueueStatus.waiting => 'waiting',
    QueueStatus.reserved => 'reserved',
    QueueStatus.onTheWay => 'on_the_way',
    QueueStatus.seated => 'seated',
    QueueStatus.completed => 'completed',
    QueueStatus.skipped => 'skipped',
    QueueStatus.cancelled => 'cancelled',
    QueueStatus.noShow => 'no_show',
    QueueStatus.expired => 'expired',
  };

  static QueueStatus fromWireName(String? value) {
    for (final status in QueueStatus.values) {
      if (status.wireName == value) return status;
    }
    throw FormatException(
      'Unknown queue status "${value ?? '<missing>'}".',
      value,
    );
  }

  bool canTransitionTo(QueueStatus next) {
    return switch (this) {
      QueueStatus.waiting => {
        QueueStatus.reserved,
        QueueStatus.seated,
        QueueStatus.skipped,
        QueueStatus.cancelled,
        QueueStatus.noShow,
        QueueStatus.expired,
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
      QueueStatus.noShow ||
      QueueStatus.expired => false,
    };
  }

  bool get canBeCancelledByCustomer => switch (this) {
    QueueStatus.waiting || QueueStatus.reserved || QueueStatus.onTheWay => true,
    QueueStatus.seated ||
    QueueStatus.completed ||
    QueueStatus.skipped ||
    QueueStatus.cancelled ||
    QueueStatus.noShow ||
    QueueStatus.expired => false,
  };

  bool get isTerminal => switch (this) {
    QueueStatus.completed ||
    QueueStatus.skipped ||
    QueueStatus.cancelled ||
    QueueStatus.noShow ||
    QueueStatus.expired => true,
    QueueStatus.waiting ||
    QueueStatus.reserved ||
    QueueStatus.onTheWay ||
    QueueStatus.seated => false,
  };

  bool get isLiveQueueVisible => switch (this) {
    QueueStatus.waiting => true,
    QueueStatus.reserved ||
    QueueStatus.onTheWay ||
    QueueStatus.seated ||
    QueueStatus.completed ||
    QueueStatus.skipped ||
    QueueStatus.cancelled ||
    QueueStatus.noShow ||
    QueueStatus.expired => false,
  };
}
