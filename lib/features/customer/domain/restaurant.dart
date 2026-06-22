class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.brandName,
    required this.contactPhone,
    required this.isActive,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String brandName;
  final String contactPhone;
  final bool isActive;
  final String? logoUrl;

  factory Restaurant.fromMap(String id, Map<String, dynamic> data) {
    return Restaurant(
      id: id,
      name: data['name'] as String? ?? '',
      brandName: data['brandName'] as String? ?? '',
      contactPhone: data['contactPhone'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      logoUrl: data['logoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'brandName': brandName,
    'contactPhone': contactPhone,
    'isActive': isActive,
    'logoUrl': logoUrl,
  };
}
