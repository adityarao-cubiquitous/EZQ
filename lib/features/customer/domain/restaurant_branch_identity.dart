class RestaurantBranchIdentity {
  const RestaurantBranchIdentity({
    required this.restaurantName,
    required this.branchName,
  });

  final String restaurantName;
  final String branchName;
}

const _knownRestaurantBranchIdentities = <String, RestaurantBranchIdentity>{
  'the-spice-house-indiranagar': RestaurantBranchIdentity(
    restaurantName: 'The Spice House',
    branchName: 'Indiranagar',
  ),
  'cubbon-curry-indiranagar': RestaurantBranchIdentity(
    restaurantName: 'Cubbon Curry',
    branchName: 'Indiranagar',
  ),
  'noodle-yard-indiranagar': RestaurantBranchIdentity(
    restaurantName: 'Noodle Yard',
    branchName: 'Indiranagar',
  ),
  'taco-tawa-indiranagar': RestaurantBranchIdentity(
    restaurantName: 'Taco Tawa',
    branchName: 'Indiranagar',
  ),
  'dosa-lab-indiranagar': RestaurantBranchIdentity(
    restaurantName: 'Dosa Lab',
    branchName: 'Indiranagar',
  ),
  'pasta-pepper-hal-2nd-stage': RestaurantBranchIdentity(
    restaurantName: 'Pasta Pepper',
    branchName: 'HAL 2nd Stage',
  ),
  'biryani-bay-domlur-edge': RestaurantBranchIdentity(
    restaurantName: 'Biryani Bay',
    branchName: 'Domlur Edge',
  ),
  'momo-mill-indiranagar-metro': RestaurantBranchIdentity(
    restaurantName: 'Momo Mill',
    branchName: 'Indiranagar Metro',
  ),
  'salad-studio-12th-main': RestaurantBranchIdentity(
    restaurantName: 'Salad Studio',
    branchName: '12th Main',
  ),
  'grill-garden-old-airport-road': RestaurantBranchIdentity(
    restaurantName: 'Grill Garden',
    branchName: 'Old Airport Road',
  ),
};

RestaurantBranchIdentity resolveRestaurantBranchIdentity({
  required String restaurantBranchSlug,
  String? restaurantName,
  String? branchName,
  String? legacyBranchName,
  String? displayName,
  String? restaurantSlug,
  String? branchSlug,
}) {
  final canonicalSlug = restaurantBranchSlug.trim().toLowerCase();
  var resolvedRestaurantName = _nonEmpty(restaurantName);
  var resolvedBranchName = _nonEmpty(branchName) ?? _nonEmpty(legacyBranchName);

  final combinedDisplayName = _splitDisplayName(displayName);
  resolvedRestaurantName ??= combinedDisplayName?.restaurantName;
  resolvedBranchName ??= combinedDisplayName?.branchName;

  final knownIdentity = _knownRestaurantBranchIdentities[canonicalSlug];
  resolvedRestaurantName ??= knownIdentity?.restaurantName;
  resolvedBranchName ??= knownIdentity?.branchName;

  final separateRestaurantSlug = _nonEmpty(restaurantSlug);
  final separateBranchSlug = _nonEmpty(branchSlug);
  if (separateRestaurantSlug != null &&
      separateBranchSlug != null &&
      (separateRestaurantSlug.toLowerCase() != canonicalSlug ||
          separateBranchSlug.toLowerCase() != canonicalSlug)) {
    resolvedRestaurantName ??= _titleFromSlug(separateRestaurantSlug);
    resolvedBranchName ??= _titleFromSlug(separateBranchSlug);
  }

  final derivedIdentity = _deriveUnknownIdentity(canonicalSlug);
  return RestaurantBranchIdentity(
    restaurantName: resolvedRestaurantName ?? derivedIdentity.restaurantName,
    branchName: resolvedBranchName ?? derivedIdentity.branchName,
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

RestaurantBranchIdentity _deriveUnknownIdentity(String canonicalSlug) {
  final parts = canonicalSlug
      .split('-')
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return const RestaurantBranchIdentity(
      restaurantName: 'Restaurant',
      branchName: 'Main',
    );
  }
  if (parts.length == 1) {
    return RestaurantBranchIdentity(
      restaurantName: _titleFromParts(parts),
      branchName: 'Main',
    );
  }

  return RestaurantBranchIdentity(
    restaurantName: _titleFromParts(parts.sublist(0, parts.length - 1)),
    branchName: _titleFromParts(parts.sublist(parts.length - 1)),
  );
}

String _titleFromSlug(String slug) => _titleFromParts(
  slug.split('-').where((part) => part.trim().isNotEmpty).toList(),
);

String _titleFromParts(List<String> parts) {
  const acronyms = {'hal', 'btm', 'jp', 'iim'};
  return parts
      .map((part) {
        final normalized = part.trim().toLowerCase();
        if (acronyms.contains(normalized)) return normalized.toUpperCase();
        if (normalized.isEmpty) return normalized;
        return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
      })
      .join(' ');
}
