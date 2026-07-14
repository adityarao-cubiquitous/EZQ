class FirestorePaths {
  const FirestorePaths._();

  static String restaurantBranch(String restaurantBranchId) =>
      'restaurantBranches/$restaurantBranchId';

  static bool isRestaurantBranchRoute(String restaurantId, String branchId) =>
      restaurantId == branchId;

  static String restaurantBranchIdFromRoute(
    String restaurantId,
    String branchId,
  ) {
    if (restaurantId == branchId) return restaurantId;
    return '$restaurantId-$branchId';
  }

  static String customerRoute(String restaurantId, String branchId) {
    return '/customer/${restaurantBranchIdFromRoute(restaurantId, branchId)}';
  }

  static String customerStatusRoute(
    String restaurantId,
    String branchId,
    String queueEntryId,
  ) {
    return '${customerRoute(restaurantId, branchId)}/status/$queueEntryId';
  }

  static String customerReadyRoute(
    String restaurantId,
    String branchId,
    String queueEntryId,
  ) {
    return '${customerRoute(restaurantId, branchId)}/ready/$queueEntryId';
  }

  static String customerSeatedRoute(
    String restaurantId,
    String branchId,
    String queueEntryId,
  ) {
    return '${customerRoute(restaurantId, branchId)}/seated/$queueEntryId';
  }

  static String adminRoute(String restaurantId, String branchId) {
    return '/admin/${restaurantBranchIdFromRoute(restaurantId, branchId)}';
  }

  static String branch(String restaurantId, String branchId) {
    return restaurantBranch(
      restaurantBranchIdFromRoute(restaurantId, branchId),
    );
  }

  static String tables(String restaurantId, String branchId) =>
      '${branch(restaurantId, branchId)}/tables';

  static String table(String restaurantId, String branchId, String tableId) =>
      '${tables(restaurantId, branchId)}/$tableId';

  static String queueEntries(String restaurantId, String branchId) =>
      '${branch(restaurantId, branchId)}/queueEntries';

  static String queueEntry(
    String restaurantId,
    String branchId,
    String queueEntryId,
  ) => '${queueEntries(restaurantId, branchId)}/$queueEntryId';

  static String dailyCounter(
    String restaurantId,
    String branchId,
    String businessDate,
  ) => '${branch(restaurantId, branchId)}/dailyCounters/$businessDate';

  static String admin(String restaurantId, String adminUserId) =>
      rootAdmin(adminUserId);

  static String rootAdmin(String adminUserId) => 'admins/$adminUserId';

  static String customer(String customerId) => 'customers/$customerId';

  static String customerVisit(String customerId, String visitId) =>
      '${customer(customerId)}/visits/$visitId';
}
