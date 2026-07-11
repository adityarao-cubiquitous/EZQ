import 'dart:async';

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
    final restaurantBranchId = FirestorePaths.restaurantBranchIdFromRoute(
      restaurantSlug,
      branchSlug,
    );
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

    return CustomerBranchLink(
      restaurantId: restaurantBranchId,
      restaurantName:
          branchData['restaurantName'] as String? ??
          branchData['displayName'] as String? ??
          restaurantBranchId,
      branch: Branch.fromMap(branchSnapshot.id, branchData),
    );
  }

  @override
  Future<String> resolveBranchSlug({
    required String restaurantId,
    required String branchSlug,
  }) async {
    final restaurantBranchId = FirestorePaths.restaurantBranchIdFromRoute(
      restaurantId,
      branchSlug,
    );
    final path = FirestorePaths.restaurantBranch(restaurantBranchId);
    final snapshot = await _firestore
        .doc(path)
        .snapshots()
        .first
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw TimeoutException('Timed out reading $path'),
        );
    if (snapshot.exists) return restaurantBranchId;
    throw StateError('RestaurantBranch $restaurantBranchId was not found.');
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
