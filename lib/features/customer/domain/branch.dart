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
    this.averageTurnoverMinutes,
    this.restaurantId,
    this.restaurantName,
    this.branchSlug,
    this.queueUrl,
    this.qrImageUrl,
    this.qrSvgUrl,
    this.cuisine,
    this.logoUrl,
    this.latitude,
    this.longitude,
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
  final int? averageTurnoverMinutes;
  final String? restaurantId;
  final String? restaurantName;
  final String? branchSlug;
  final String? queueUrl;
  final String? qrImageUrl;
  final String? qrSvgUrl;
  final String? cuisine;
  final String? logoUrl;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  factory Branch.fromMap(String id, Map<String, dynamic> data) {
    final geoPoint = data['geoPoint'] ?? data['geoLocation'];
    double? geoLatitude;
    double? geoLongitude;
    if (geoPoint != null) {
      try {
        geoLatitude = (geoPoint.latitude as num?)?.toDouble();
        geoLongitude = (geoPoint.longitude as num?)?.toDouble();
      } catch (_) {
        if (geoPoint is Map<String, dynamic>) {
          geoLatitude = (geoPoint['latitude'] as num?)?.toDouble();
          geoLongitude = (geoPoint['longitude'] as num?)?.toDouble();
        }
      }
    }
    return Branch(
      id: id,
      name:
          data['branchName'] as String? ??
          data['name'] as String? ??
          data['displayName'] as String? ??
          '',
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
      averageTurnoverMinutes: data['averageTurnoverMinutes'] as int?,
      restaurantId: data['restaurantId'] as String?,
      restaurantName: data['restaurantName'] as String?,
      branchSlug: id,
      queueUrl: data['queueUrl'] as String?,
      qrImageUrl: data['qrImageUrl'] as String?,
      qrSvgUrl: data['qrSvgUrl'] as String?,
      cuisine: data['cuisine'] as String?,
      logoUrl: data['logoUrl'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble() ?? geoLatitude,
      longitude: (data['longitude'] as num?)?.toDouble() ?? geoLongitude,
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
    'averageTurnoverMinutes': averageTurnoverMinutes,
    'restaurantId': restaurantId,
    'restaurantName': restaurantName,
    'queueUrl': queueUrl,
    'qrImageUrl': qrImageUrl,
    'qrSvgUrl': qrSvgUrl,
    'cuisine': cuisine,
    'logoUrl': logoUrl,
    'latitude': latitude,
    'longitude': longitude,
  };
}
