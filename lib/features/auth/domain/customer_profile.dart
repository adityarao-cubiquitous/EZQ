class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.displayName,
    required this.phone,
    required this.authProvider,
    required this.preferredLanguage,
    required this.defaultPartySize,
    required this.appInstalled,
    this.email,
  });

  final String id;
  final String displayName;
  final String phone;
  final String? email;
  final String authProvider;
  final String preferredLanguage;
  final int defaultPartySize;
  final bool appInstalled;
}
