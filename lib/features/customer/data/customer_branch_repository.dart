import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/branch.dart';

class CustomerBranchDisplay {
  const CustomerBranchDisplay({
    required this.restaurantId,
    required this.branchId,
    required this.restaurantName,
    required this.branchName,
    required this.isRestaurantActive,
    required this.isBranchActive,
  });

  final String restaurantId;
  final String branchId;
  final String restaurantName;
  final String branchName;
  final bool isRestaurantActive;
  final bool isBranchActive;

  bool get canJoinQueue => isRestaurantActive && isBranchActive;
}

typedef CustomerBranchKey = ({String restaurantId, String branchId});

abstract class CustomerBranchRepository {
  Stream<CustomerBranchDisplay> watchBranchDisplay({
    required String restaurantId,
    required String branchId,
  });
}

class FirebaseCustomerBranchRepository implements CustomerBranchRepository {
  FirebaseCustomerBranchRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<CustomerBranchDisplay> watchBranchDisplay({
    required String restaurantId,
    required String branchId,
  }) {
    final branchRef = _firestore.doc(
      FirestorePaths.branch(restaurantId, branchId),
    );

    return branchRef.snapshots().asyncMap((branchSnapshot) async {
      final branchData = branchSnapshot.data();
      if (!branchSnapshot.exists || branchData == null) {
        throw const CustomerBranchException(
          CustomerBranchFailure.branchNotFound,
        );
      }

      final restaurantSnapshot = await _firestore
          .doc(FirestorePaths.restaurant(restaurantId))
          .get();
      final restaurantData = restaurantSnapshot.data();
      if (!restaurantSnapshot.exists || restaurantData == null) {
        throw const CustomerBranchException(
          CustomerBranchFailure.restaurantNotFound,
        );
      }

      final branch = Branch.fromMap(branchSnapshot.id, branchData);
      final restaurantName =
          branch.restaurantName ??
          restaurantData['brandName'] as String? ??
          restaurantData['name'] as String? ??
          restaurantId;
      final branchName = branch.name.isEmpty ? branchId : branch.name;

      return CustomerBranchDisplay(
        restaurantId: restaurantId,
        branchId: branchSnapshot.id,
        restaurantName: restaurantName,
        branchName: branchName,
        isRestaurantActive: restaurantData['isActive'] as bool? ?? true,
        isBranchActive: branch.isActive,
      );
    });
  }
}

class RouteCustomerBranchRepository implements CustomerBranchRepository {
  const RouteCustomerBranchRepository();

  @override
  Stream<CustomerBranchDisplay> watchBranchDisplay({
    required String restaurantId,
    required String branchId,
  }) {
    return Stream.value(
      CustomerBranchDisplay(
        restaurantId: restaurantId,
        branchId: branchId,
        restaurantName: restaurantId,
        branchName: branchId,
        isRestaurantActive: true,
        isBranchActive: true,
      ),
    );
  }
}

enum CustomerBranchFailure { restaurantNotFound, branchNotFound }

class CustomerBranchException implements Exception {
  const CustomerBranchException(this.failure);

  final CustomerBranchFailure failure;
}

final customerBranchRepositoryProvider = Provider<CustomerBranchRepository>((
  ref,
) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase) return FirebaseCustomerBranchRepository();
  return const RouteCustomerBranchRepository();
});

final customerBranchDisplayProvider = StreamProvider.autoDispose
    .family<CustomerBranchDisplay, CustomerBranchKey>((ref, key) {
      return ref
          .watch(customerBranchRepositoryProvider)
          .watchBranchDisplay(
            restaurantId: key.restaurantId,
            branchId: key.branchId,
          );
    });
