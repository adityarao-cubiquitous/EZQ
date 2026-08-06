import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/branch.dart';
import '../domain/restaurant_branch_identity.dart';

enum CustomerDeepLinkFailure {
  restaurantNotFound,
  restaurantClosed,
  branchNotFound,
  branchInactive,
}

class CustomerBranchLink {
  const CustomerBranchLink({required this.identity, required this.branch});

  final RestaurantBranchIdentity identity;
  final Branch branch;

  String get restaurantBranchId => identity.restaurantBranchId;
  String get restaurantName => identity.restaurantName;
}

class CustomerDeepLinkException implements Exception {
  const CustomerDeepLinkException(this.failure);

  final CustomerDeepLinkFailure failure;
}

abstract class BranchIdentityRepository {
  Future<CustomerBranchLink> resolveCustomerBranch({
    required String restaurantBranchId,
  });
}

class FirebaseBranchIdentityRepository implements BranchIdentityRepository {
  FirebaseBranchIdentityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<CustomerBranchLink> resolveCustomerBranch({
    required String restaurantBranchId,
  }) async {
    final branchPath = FirestorePaths.restaurantBranch(restaurantBranchId);
    debugPrint('[CUSTOMER_DEEP_LINK]\npath=$branchPath');
    final DocumentSnapshot<Map<String, dynamic>> branchSnapshot;
    try {
      branchSnapshot = await _firestore
          .doc(branchPath)
          .snapshots()
          .first
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () =>
                throw TimeoutException('Timed out reading $branchPath'),
          );
    } on FirebaseException catch (error) {
      debugPrint(
        '[CUSTOMER_DEEP_LINK_ERROR]\n'
        'path=$branchPath\n'
        'code=${error.code}\n'
        'message=${error.message}',
      );
      rethrow;
    } on TimeoutException catch (error) {
      debugPrint(
        '[CUSTOMER_DEEP_LINK_ERROR]\n'
        'path=$branchPath\n'
        'code=timeout\n'
        'message=${error.message}',
      );
      rethrow;
    }
    final branchData = branchSnapshot.data();
    debugPrint(
      '[CUSTOMER_DEEP_LINK]\n'
      'path=$branchPath\n'
      'exists=${branchSnapshot.exists}\n'
      'isActive=${branchData?['isActive']}',
    );
    if (!branchSnapshot.exists || branchData == null) {
      throw const CustomerDeepLinkException(
        CustomerDeepLinkFailure.branchNotFound,
      );
    }
    if (branchData['isActive'] != true) {
      throw const CustomerDeepLinkException(
        CustomerDeepLinkFailure.branchInactive,
      );
    }

    final branch = Branch.fromMap(branchSnapshot.id, branchData);
    return CustomerBranchLink(
      identity: resolveRestaurantBranchIdentity(
        restaurantBranchId: restaurantBranchId,
        restaurantName: branch.restaurantName,
        branchName: branch.name,
      ),
      branch: branch,
    );
  }
}

class PassthroughBranchIdentityRepository implements BranchIdentityRepository {
  @override
  Future<CustomerBranchLink> resolveCustomerBranch({
    required String restaurantBranchId,
  }) async {
    final branch = Branch.fromMap(restaurantBranchId, {'isActive': true});
    return CustomerBranchLink(
      identity: resolveRestaurantBranchIdentity(
        restaurantBranchId: restaurantBranchId,
        restaurantName: branch.restaurantName,
        branchName: branch.name,
      ),
      branch: branch,
    );
  }
}

final branchIdentityRepositoryProvider = Provider<BranchIdentityRepository>((
  ref,
) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase || kIsWeb) {
    return FirebaseBranchIdentityRepository();
  }
  return PassthroughBranchIdentityRepository();
});

final customerBranchLinkProvider =
    FutureProvider.family<CustomerBranchLink, String>((
      ref,
      restaurantBranchId,
    ) {
      return ref
          .watch(branchIdentityRepositoryProvider)
          .resolveCustomerBranch(restaurantBranchId: restaurantBranchId);
    }, retry: (_, _) => null);
