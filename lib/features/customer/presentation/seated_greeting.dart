String seatedGreeting(String partyName) {
  final normalizedName = partyName.trim();
  if (normalizedName.isEmpty) return 'Enjoy your meal!';
  return '$normalizedName, enjoy your meal!';
}
