class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.timezone,
    required this.qrSlug,
    required this.isActive,
    required this.averageDiningMinutes,
    required this.averageCleaningMinutes,
    required this.holdMinutes,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String country;
  final String timezone;
  final String qrSlug;
  final bool isActive;
  final int averageDiningMinutes;
  final int averageCleaningMinutes;
  final int holdMinutes;

  factory Branch.fromMap(String id, Map<String, dynamic> data) {
    return Branch(
      id: id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      city: data['city'] as String? ?? '',
      state: data['state'] as String? ?? '',
      country: data['country'] as String? ?? 'India',
      timezone: data['timezone'] as String? ?? 'Asia/Kolkata',
      qrSlug: data['qrSlug'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      averageDiningMinutes: data['averageDiningMinutes'] as int? ?? 35,
      averageCleaningMinutes: data['averageCleaningMinutes'] as int? ?? 5,
      holdMinutes: data['holdMinutes'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'city': city,
    'state': state,
    'country': country,
    'timezone': timezone,
    'qrSlug': qrSlug,
    'isActive': isActive,
    'averageDiningMinutes': averageDiningMinutes,
    'averageCleaningMinutes': averageCleaningMinutes,
    'holdMinutes': holdMinutes,
  };
}
