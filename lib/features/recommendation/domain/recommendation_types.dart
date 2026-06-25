enum RecommendationType {
  exactMatch,
  sharedMatch,
  largerAlternative,
  combinedTable,
}

enum SeatingPreference {
  anyAvailable,
  emptyTableOnly;

  static SeatingPreference fromWireName(String? value) {
    return value == 'EMPTY_TABLE_ONLY' ? emptyTableOnly : anyAvailable;
  }

  String get wireName =>
      this == emptyTableOnly ? 'EMPTY_TABLE_ONLY' : 'ANY_AVAILABLE';
}
