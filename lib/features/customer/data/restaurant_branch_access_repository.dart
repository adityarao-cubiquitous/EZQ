import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';

enum CustomerRouteBlockReason {
  restaurantUnavailable,
  branchUnavailable,
  setupIncomplete,
  qrDisabled,
}

class CustomerRouteAccess {
  const CustomerRouteAccess.allowed() : blockReason = null;

  const CustomerRouteAccess.blocked(this.blockReason);

  final CustomerRouteBlockReason? blockReason;

  bool get isAllowed => blockReason == null;
}

abstract class RestaurantBranchAccessRepository {
  Future<CustomerRouteAccess> checkCustomerAccess(String restaurantBranchId);
}

class FirebaseRestaurantBranchAccessRepository
    implements RestaurantBranchAccessRepository {
  FirebaseRestaurantBranchAccessRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<CustomerRouteAccess> checkCustomerAccess(
    String restaurantBranchId,
  ) async {
    final branchSnapshot = await _firestore
        .doc(FirestorePaths.restaurantBranch(restaurantBranchId))
        .get()
        .timeout(const Duration(seconds: 8));
    final branchData = branchSnapshot.data();
    if (!branchSnapshot.exists || branchData == null) {
      return const CustomerRouteAccess.blocked(
        CustomerRouteBlockReason.setupIncomplete,
      );
    }

    final restaurantId = (branchData['restaurantId'] as String? ?? '').trim();
    if (restaurantId.isNotEmpty) {
      final restaurantSnapshot = await _firestore
          .doc('restaurants/$restaurantId')
          .get()
          .timeout(const Duration(seconds: 8));
      if (restaurantSnapshot.exists) {
        final restaurantData = restaurantSnapshot.data();
        if (restaurantData?['isActive'] != true) {
          return const CustomerRouteAccess.blocked(
            CustomerRouteBlockReason.restaurantUnavailable,
          );
        }
      }
    } else if (branchData['restaurantIsActive'] == false) {
      return const CustomerRouteAccess.blocked(
        CustomerRouteBlockReason.restaurantUnavailable,
      );
    }

    if (branchData['isActive'] != true) {
      return const CustomerRouteAccess.blocked(
        CustomerRouteBlockReason.branchUnavailable,
      );
    }
    if (branchData['onboardingCompleted'] != true ||
        branchData['provisioningStatus'] != 'completed') {
      return const CustomerRouteAccess.blocked(
        CustomerRouteBlockReason.setupIncomplete,
      );
    }
    if (branchData['qrEnabled'] != true) {
      return const CustomerRouteAccess.blocked(
        CustomerRouteBlockReason.qrDisabled,
      );
    }
    return const CustomerRouteAccess.allowed();
  }
}

class PassthroughRestaurantBranchAccessRepository
    implements RestaurantBranchAccessRepository {
  @override
  Future<CustomerRouteAccess> checkCustomerAccess(String restaurantBranchId) {
    return Future.value(const CustomerRouteAccess.allowed());
  }
}

final restaurantBranchAccessRepositoryProvider =
    Provider<RestaurantBranchAccessRepository>((ref) {
      const useFirebase = bool.fromEnvironment('USE_FIREBASE');
      if (useFirebase || kIsWeb) {
        return FirebaseRestaurantBranchAccessRepository();
      }
      return PassthroughRestaurantBranchAccessRepository();
    });
