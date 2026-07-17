import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/restaurant_branch_readiness.dart';

enum CustomerRouteBlockReason {
  restaurantUnavailable,
  branchUnavailable,
  setupIncomplete,
  qrDisabled,
}

CustomerRouteBlockReason _customerBlockReasonFromReadiness(
  RestaurantBranchReadinessBlockReason reason,
) {
  return switch (reason) {
    RestaurantBranchReadinessBlockReason.restaurantUnavailable =>
      CustomerRouteBlockReason.restaurantUnavailable,
    RestaurantBranchReadinessBlockReason.branchUnavailable =>
      CustomerRouteBlockReason.branchUnavailable,
    RestaurantBranchReadinessBlockReason.setupIncomplete =>
      CustomerRouteBlockReason.setupIncomplete,
    RestaurantBranchReadinessBlockReason.qrDisabled =>
      CustomerRouteBlockReason.qrDisabled,
  };
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
    final restaurantId = (branchData?['restaurantId'] as String? ?? '').trim();
    var restaurantExists = false;
    Map<String, dynamic>? restaurantData;
    if (restaurantId.isNotEmpty) {
      final restaurantSnapshot = await _firestore
          .doc('restaurants/$restaurantId')
          .get()
          .timeout(const Duration(seconds: 8));
      if (restaurantSnapshot.exists) {
        restaurantExists = true;
        restaurantData = restaurantSnapshot.data();
      }
    }

    final readiness = evaluateRestaurantBranchReadiness(
      branchExists: branchSnapshot.exists,
      branchData: branchData,
      restaurantExists: restaurantExists,
      restaurantData: restaurantData,
    );
    final blockReason = readiness.blockReason;
    if (blockReason != null) {
      return CustomerRouteAccess.blocked(
        _customerBlockReasonFromReadiness(blockReason),
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
