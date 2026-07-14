enum OnboardingProvisioningStep {
  updateRestaurantBranch,
  createFloors,
  createTables,
  createSettings,
  updateAdmin;

  String get label {
    return switch (this) {
      OnboardingProvisioningStep.updateRestaurantBranch =>
        'Update Restaurant Branch',
      OnboardingProvisioningStep.createFloors => 'Create Floors',
      OnboardingProvisioningStep.createTables => 'Create Tables',
      OnboardingProvisioningStep.createSettings => 'Create Settings',
      OnboardingProvisioningStep.updateAdmin => 'Update Admin',
    };
  }
}

enum ProvisioningStepStatus { pending, running, complete, failed }

class ProvisioningStepProgress {
  const ProvisioningStepProgress({required this.step, required this.status});

  final OnboardingProvisioningStep step;
  final ProvisioningStepStatus status;

  ProvisioningStepProgress copyWith({ProvisioningStepStatus? status}) {
    return ProvisioningStepProgress(step: step, status: status ?? this.status);
  }
}

class RestaurantOnboardingRequest {
  const RestaurantOnboardingRequest({
    required this.restaurantBranchId,
    required this.restaurantName,
    required this.branchName,
    required this.area,
    required this.address,
    required this.floorCount,
    required this.selectedTableCapacities,
    required this.tableCountsByFloor,
    required this.totalTables,
    required this.totalSeats,
  });

  final String restaurantBranchId;
  final String restaurantName;
  final String branchName;
  final String area;
  final String address;
  final int floorCount;
  final List<int> selectedTableCapacities;
  final List<List<int>> tableCountsByFloor;
  final int totalTables;
  final int totalSeats;
}

class RestaurantOnboardingResult {
  const RestaurantOnboardingResult({
    required this.restaurantBranchId,
    required this.createdAt,
    required this.adminEmail,
    required this.qrUrl,
  });

  final String restaurantBranchId;
  final DateTime createdAt;
  final String adminEmail;
  final String qrUrl;

  String get restaurantId => restaurantBranchId;

  String get branchId => restaurantBranchId;
}

class CompletedRestaurantOnboarding {
  const CompletedRestaurantOnboarding({required this.restaurantBranchId});

  final String restaurantBranchId;

  String get restaurantId => restaurantBranchId;

  String get branchId => restaurantBranchId;
}

class RestaurantBranchAdminContext {
  const RestaurantBranchAdminContext({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.restaurantBranchId,
    required this.role,
    required this.isActive,
    required this.onboardingCompleted,
    this.provisioningStatus = 'pending',
    this.branchActive = true,
    required this.restaurantName,
    required this.branchName,
    required this.area,
    required this.address,
    required this.slug,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String restaurantBranchId;
  final String role;
  final bool isActive;
  final bool onboardingCompleted;
  final String provisioningStatus;
  final bool branchActive;
  final String restaurantName;
  final String branchName;
  final String area;
  final String address;
  final String slug;

  String get displayName => '$restaurantName - $branchName';

  bool get isProvisioningCompleted =>
      onboardingCompleted && provisioningStatus == 'completed' && branchActive;
}

class RestaurantOnboardingFailure implements Exception {
  const RestaurantOnboardingFailure({
    required this.step,
    required this.message,
    this.cause,
  });

  final OnboardingProvisioningStep step;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
