class RestaurantBranchIdentity {
  const RestaurantBranchIdentity({
    required this.restaurantBranchId,
    required this.restaurantName,
    required this.branchName,
    this.address = '',
    this.logoUrl,
  });

  final String restaurantBranchId;
  final String restaurantName;
  final String branchName;
  final String address;
  final String? logoUrl;

  String get branchLabel {
    final normalized = branchName.trim();
    if (normalized.toLowerCase().endsWith(' branch')) return normalized;
    return '$normalized Branch';
  }

  String get addressLabel {
    final normalized = address.trim();
    return normalized.isEmpty ? 'Address unavailable' : normalized;
  }

  String get initials {
    final words = restaurantName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .toList();
    if (words.isEmpty) return '';
    return words.map((word) => word[0].toUpperCase()).join();
  }
}

RestaurantBranchIdentity resolveRestaurantBranchIdentity({
  required String restaurantBranchId,
  String? restaurantName,
  String? branchName,
  String? legacyBranchName,
  String? displayName,
  String? restaurantSlug,
  String? branchSlug,
  String? address,
  String? logoUrl,
}) {
  var resolvedRestaurantName = _nonEmpty(restaurantName);
  var resolvedBranchName = _nonEmpty(branchName) ?? _nonEmpty(legacyBranchName);

  final combinedDisplayName = _splitDisplayName(displayName);
  resolvedRestaurantName ??= combinedDisplayName?.restaurantName;
  resolvedBranchName ??= combinedDisplayName?.branchName;

  final separateRestaurantSlug = _nonEmpty(restaurantSlug);
  final separateBranchSlug = _nonEmpty(branchSlug);
  final canonicalId = restaurantBranchId.trim().toLowerCase();
  if (separateRestaurantSlug != null &&
      separateBranchSlug != null &&
      (separateRestaurantSlug.toLowerCase() != canonicalId ||
          separateBranchSlug.toLowerCase() != canonicalId)) {
    resolvedRestaurantName ??= _titleFromSlug(separateRestaurantSlug);
    resolvedBranchName ??= _titleFromSlug(separateBranchSlug);
  }

  return RestaurantBranchIdentity(
    restaurantBranchId: canonicalId,
    restaurantName:
        resolvedRestaurantName ??
        _titleFromSlug(canonicalId, fallback: 'Restaurant'),
    branchName: resolvedBranchName ?? 'Main',
    address: _nonEmpty(address) ?? '',
    logoUrl: _nonEmpty(logoUrl),
  );
}

String? _nonEmpty(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

({String restaurantName, String branchName})? _splitDisplayName(
  String? displayName,
) {
  final normalized = _nonEmpty(displayName);
  if (normalized == null) return null;
  final separatorIndex = normalized.indexOf(' - ');
  if (separatorIndex <= 0 || separatorIndex >= normalized.length - 3) {
    return null;
  }
  return (
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
