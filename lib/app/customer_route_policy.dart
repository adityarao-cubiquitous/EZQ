const invalidCustomerLinkPath = '/invalid-customer-link';

String? resolveLegacyCustomerRouteRedirect(String currentPath) {
  final segments = Uri.parse(currentPath).pathSegments;
  if (segments.length != 3 || segments.first != 'customer') return null;

  const canonicalChildPaths = {'menu', 'support'};
  if (canonicalChildPaths.contains(segments.last)) return null;
  return invalidCustomerLinkPath;
}
