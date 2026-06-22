import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class AuthRepository {
  Future<void> signInAdmin({required String email, required String password});

  Future<void> signOut();
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});
