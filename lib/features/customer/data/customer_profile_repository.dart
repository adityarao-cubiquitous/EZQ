import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/customer_profile.dart';

abstract class CustomerProfileRepository {
  Future<CustomerProfile?> getProfile(String customerId);
}

class MockCustomerProfileRepository implements CustomerProfileRepository {
  @override
  Future<CustomerProfile?> getProfile(String customerId) async {
    return null;
  }
}

final customerProfileRepositoryProvider = Provider<CustomerProfileRepository>((
  ref,
) {
  return MockCustomerProfileRepository();
});
