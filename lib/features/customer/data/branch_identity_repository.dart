import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<String> resolveBranchId({
    required String restaurantId,
    required String branchSlugOrId,
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

    final directBranchSnapshot = await _firestore
        .doc(FirestorePaths.branch(restaurantSlug, branchSlug))
        .get();
    QueryDocumentSnapshot<Map<String, dynamic>>? branchQueryDoc;
    DocumentSnapshot<Map<String, dynamic>>? branchSnapshot =
        directBranchSnapshot.exists ? directBranchSnapshot : null;

    if (branchSnapshot == null) {
      final slugSnapshot = await _firestore
          .collection(FirestorePaths.branches(restaurantSlug))
          .where('branchSlug', isEqualTo: branchSlug)
          .limit(2)
          .get();
      if (slugSnapshot.docs.isEmpty) {
        throw const CustomerDeepLinkException(
          CustomerDeepLinkFailure.branchNotFound,
        );
      }
      if (slugSnapshot.docs.length > 1) {
        throw const CustomerDeepLinkException(
          CustomerDeepLinkFailure.branchNotFound,
        );
      }
      branchQueryDoc = slugSnapshot.docs.single;
    }

    final branchId = branchSnapshot?.id ?? branchQueryDoc!.id;
    final branchData = branchSnapshot?.data() ?? branchQueryDoc!.data();
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
      branch: Branch.fromMap(branchId, branchData),
    );
  }

  @override
  Future<String> resolveBranchId({
    required String restaurantId,
    required String branchSlugOrId,
  }) async {
    final directRef = _firestore.doc(
      FirestorePaths.branch(restaurantId, branchSlugOrId),
    );
    final directSnapshot = await directRef.get();
    if (directSnapshot.exists) return branchSlugOrId;

    final slugSnapshot = await _firestore
        .collection(FirestorePaths.branches(restaurantId))
        .where('branchSlug', isEqualTo: branchSlugOrId)
        .limit(2)
        .get();

    if (slugSnapshot.docs.length == 1) {
      final data = slugSnapshot.docs.single.data();
      return data['branchId'] as String? ?? slugSnapshot.docs.single.id;
    }
    if (slugSnapshot.docs.length > 1) {
      throw StateError(
        'Multiple branches match slug $branchSlugOrId for $restaurantId.',
      );
    }

    throw StateError('Branch $branchSlugOrId was not found for $restaurantId.');
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
        branchId: branchSlug,
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
  Future<String> resolveBranchId({
    required String restaurantId,
    required String branchSlugOrId,
  }) async {
    return branchSlugOrId;
  }
}

final branchIdentityRepositoryProvider = Provider<BranchIdentityRepository>((
  ref,
) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase) {
    return FirebaseBranchIdentityRepository();
  }
  return PassthroughBranchIdentityRepository();
});
