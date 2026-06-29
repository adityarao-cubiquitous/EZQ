import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';

abstract class BranchIdentityRepository {
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
