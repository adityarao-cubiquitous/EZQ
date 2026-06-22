enum TableStatus {
  available,
  reserved,
  occupied,
  blocked;

  String get wireName => name;

  static TableStatus fromWireName(String? value) {
    if (value == 'cleaning') return TableStatus.available;
    return TableStatus.values.firstWhere(
      (status) => status.wireName == value,
      orElse: () => TableStatus.available,
    );
  }

  bool canTransitionTo(TableStatus next) {
    return switch (this) {
      TableStatus.available => {
        TableStatus.reserved,
        TableStatus.occupied,
        TableStatus.blocked,
      }.contains(next),
      TableStatus.reserved => {
        TableStatus.occupied,
        TableStatus.available,
      }.contains(next),
      TableStatus.occupied => next == TableStatus.available,
      TableStatus.blocked => next == TableStatus.available,
    };
  }
}
