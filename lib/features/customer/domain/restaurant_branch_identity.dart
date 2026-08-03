class RestaurantBranchIdentity {
  const RestaurantBranchIdentity({
    required this.restaurantName,
    required this.branchName,
  });

  final String restaurantName;
  final String branchName;
}

RestaurantBranchIdentity resolveRestaurantBranchIdentity({
  required String restaurantBranchSlug,
  String? restaurantName,
  String? branchName,
  String? legacyBranchName,
  String? displayName,
  String? restaurantSlug,
  String? branchSlug,
}) {
  var resolvedRestaurantName = _nonEmpty(restaurantName);
  var resolvedBranchName = _nonEmpty(branchName) ?? _nonEmpty(legacyBranchName);

  final combinedDisplayName = _splitDisplayName(displayName);
  resolvedRestaurantName ??= combinedDisplayName?.restaurantName;
  resolvedBranchName ??= combinedDisplayName?.branchName;

  final separateRestaurantSlug = _nonEmpty(restaurantSlug);
  final separateBranchSlug = _nonEmpty(branchSlug);
  final canonicalSlug = restaurantBranchSlug.trim().toLowerCase();
  if (separateRestaurantSlug != null &&
      separateBranchSlug != null &&
      (separateRestaurantSlug.toLowerCase() != canonicalSlug ||
          separateBranchSlug.toLowerCase() != canonicalSlug)) {
    resolvedRestaurantName ??= _titleFromSlug(separateRestaurantSlug);
    resolvedBranchName ??= _titleFromSlug(separateBranchSlug);
  }

  return RestaurantBranchIdentity(
    restaurantName:
        resolvedRestaurantName ??
        _titleFromSlug(canonicalSlug, fallback: 'Restaurant'),
    branchName: resolvedBranchName ?? 'Main',
  );
}

String? _nonEmpty(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

RestaurantBranchIdentity? _splitDisplayName(String? displayName) {
  final normalized = _nonEmpty(displayName);
  if (normalized == null) return null;
  final separatorIndex = normalized.indexOf(' - ');
  if (separatorIndex <= 0 || separatorIndex >= normalized.length - 3) {
    return null;
  }
  return RestaurantBranchIdentity(
    restaurantName: normalized.substring(0, separatorIndex).trim(),
    branchName: normalized.substring(separatorIndex + 3).trim(),
  );
}

String _titleFromSlug(String slug, {String fallback = 'Main'}) {
  final words = slug
      .split(RegExp(r'[-_]'))
      .where((part) => part.trim().isNotEmpty)
      .map(_titleWord)
      .toList();
  return words.isEmpty ? fallback : words.join(' ');
}

String _titleWord(String value) {
  final normalized = value.trim().toLowerCase();
  const acronyms = {'hal', 'btm', 'jp', 'iim'};
  if (acronyms.contains(normalized)) return normalized.toUpperCase();
  if (RegExp(r'^\d+(st|nd|rd|th)$').hasMatch(normalized)) return normalized;
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}
