import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/branch.dart';

enum CustomerDeepLinkFailure {
  restaurantNotFound,
  restaurantClosed,
  branchNotFound,
  branchInactive,
}

class CustomerBranchLink {
  const CustomerBranchLink({
    required this.restaurantId,
    required this.restaurantName,
    required this.branch,
  });

  final String restaurantId;
  final String restaurantName;
  final Branch branch;
}

class CustomerDeepLinkException implements Exception {
  const CustomerDeepLinkException(this.failure);

  final CustomerDeepLinkFailure failure;
}

abstract class BranchIdentityRepository {
  Future<CustomerBranchLink> resolveCustomerBranch({
    required String restaurantSlug,
    required String branchSlug,
  });

  Future<String> resolveBranchSlug({
    required String restaurantId,
    required String branchSlug,
  });
}

class FirebaseBranchIdentityRepository implements BranchIdentityRepository {
  FirebaseBranchIdentityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<CustomerBranchLink> resolveCustomerBranch({
    required String restaurantSlug,
    required String branchSlug,
  }) async {
    final restaurantRef = _firestore.doc(
      FirestorePaths.restaurant(restaurantSlug),
    );
    final restaurantSnapshot = await restaurantRef.get();
    final restaurantData = restaurantSnapshot.data();
    if (!restaurantSnapshot.exists || restaurantData == null) {
      throw const CustomerDeepLinkException(
        CustomerDeepLinkFailure.restaurantNotFound,
      );
    }
    if (restaurantData['isActive'] != true) {
      throw const CustomerDeepLinkException(
        CustomerDeepLinkFailure.restaurantClosed,
      );
    }

    final branchSnapshot = await _firestore
        .doc(FirestorePaths.branch(restaurantSlug, branchSlug))
        .get();
    final branchData = branchSnapshot.data();
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

    return CustomerBranchLink(
      restaurantId: restaurantSlug,
      restaurantName:
          branchData['restaurantName'] as String? ??
          restaurantData['brandName'] as String? ??
          restaurantData['name'] as String? ??
          restaurantSlug,
      branch: Branch.fromMap(branchSnapshot.id, branchData),
    );
  }

  @override
  Future<String> resolveBranchSlug({
    required String restaurantId,
    required String branchSlug,
  }) async {
    final snapshot = await _firestore
        .doc(FirestorePaths.branch(restaurantId, branchSlug))
        .get();
    if (snapshot.exists) return branchSlug;
    throw StateError('Branch $branchSlug was not found for $restaurantId.');
  }
}

class PassthroughBranchIdentityRepository implements BranchIdentityRepository {
  @override
  Future<CustomerBranchLink> resolveCustomerBranch({
    required String restaurantSlug,
    required String branchSlug,
  }) async {
    return CustomerBranchLink(
      restaurantId: restaurantSlug,
      restaurantName: restaurantSlug,
      branch: Branch(
        id: branchSlug,
        branchSlug: branchSlug,
        name: branchSlug,
        address: '',
        city: '',
        state: '',
        country: 'India',
        timezone: 'Asia/Kolkata',
        qrSlug: '$restaurantSlug-$branchSlug',
        isActive: true,
        averageDiningMinutes: 35,
        averageCleaningMinutes: 5,
        holdMinutes: 5,
      ),
    );
  }

  @override
  Future<String> resolveBranchSlug({
    required String restaurantId,
    required String branchSlug,
  }) async {
    return branchSlug;
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
