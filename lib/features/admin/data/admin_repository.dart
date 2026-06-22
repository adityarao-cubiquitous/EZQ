import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/admin_user.dart';
import '../../customer/domain/branch.dart';

abstract class AdminRepository {
  Future<AdminUser?> currentAdmin();

  Stream<List<Branch>> watchBranches(String restaurantId);
}

class MockAdminRepository implements AdminRepository {
  @override
  Future<AdminUser?> currentAdmin() async {
    return const AdminUser(
      uid: 'host-demo',
      name: 'Ravi',
      email: 'ravi@example.com',
      phone: '+919999999999',
      role: 'host',
      branchIds: ['indiranagar'],
      isActive: true,
    );
  }

  @override
  Stream<List<Branch>> watchBranches(String restaurantId) async* {
    yield const [
      Branch(
        id: 'indiranagar',
        name: 'Indiranagar',
        address: 'Indiranagar, Bengaluru',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        qrSlug: 'spice-house-indiranagar',
        isActive: true,
        averageDiningMinutes: 35,
        averageCleaningMinutes: 5,
        holdMinutes: 5,
      ),
    ];
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return MockAdminRepository();
});
