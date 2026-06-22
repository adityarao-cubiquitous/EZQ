class AdminUser {
  const AdminUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.branchIds,
    required this.isActive,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final List<String> branchIds;
  final bool isActive;

  factory AdminUser.fromMap(Map<String, dynamic> data) {
    return AdminUser(
      uid: data['uid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: data['role'] as String? ?? 'host',
      branchIds: List<String>.from(data['branchIds'] as List? ?? const []),
      isActive: data['isActive'] as bool? ?? false,
    );
  }
}
