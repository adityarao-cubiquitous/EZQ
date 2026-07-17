enum RestaurantBranchReadinessBlockReason {
  restaurantUnavailable,
  branchUnavailable,
  setupIncomplete,
  qrDisabled,
}

class RestaurantBranchReadiness {
  const RestaurantBranchReadiness._(this.blockReason);

  const RestaurantBranchReadiness.ready() : this._(null);

  const RestaurantBranchReadiness.blocked(
    RestaurantBranchReadinessBlockReason reason,
  ) : this._(reason);

  final RestaurantBranchReadinessBlockReason? blockReason;

  bool get isReady => blockReason == null;
}

RestaurantBranchReadiness evaluateRestaurantBranchReadiness({
  required bool branchExists,
  required Map<String, dynamic>? branchData,
  bool restaurantExists = false,
  Map<String, dynamic>? restaurantData,
}) {
  if (!branchExists || branchData == null) {
    return const RestaurantBranchReadiness.blocked(
      RestaurantBranchReadinessBlockReason.setupIncomplete,
    );
  }

  if (restaurantExists && restaurantData?['isActive'] != true) {
    return const RestaurantBranchReadiness.blocked(
      RestaurantBranchReadinessBlockReason.restaurantUnavailable,
    );
  }
  if (!restaurantExists && branchData['restaurantIsActive'] == false) {
    return const RestaurantBranchReadiness.blocked(
      RestaurantBranchReadinessBlockReason.restaurantUnavailable,
    );
  }

  if (branchData['isActive'] != true) {
    return const RestaurantBranchReadiness.blocked(
      RestaurantBranchReadinessBlockReason.branchUnavailable,
    );
  }
  if (branchData['onboardingCompleted'] != true) {
    return const RestaurantBranchReadiness.blocked(
      RestaurantBranchReadinessBlockReason.setupIncomplete,
    );
  }
  if (branchData['qrEnabled'] == false) {
    return const RestaurantBranchReadiness.blocked(
      RestaurantBranchReadinessBlockReason.qrDisabled,
    );
  }

  return const RestaurantBranchReadiness.ready();
}
