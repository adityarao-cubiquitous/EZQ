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

class RestaurantOnboardingDraft {
  const RestaurantOnboardingDraft({
    required this.restaurantBranchId,
    required this.currentStepIndex,
    required this.completedStepIndexes,
    required this.restaurantName,
    required this.branchName,
    required this.area,
    required this.address,
    required this.floorCount,
    required this.selectedTableCapacities,
    required this.tableCountsByFloor,
  });

  final String restaurantBranchId;
  final int currentStepIndex;
  final Set<int> completedStepIndexes;
  final String restaurantName;
  final String branchName;
  final String area;
  final String address;
  final int floorCount;
  final List<int> selectedTableCapacities;
  final List<List<int>> tableCountsByFloor;

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'restaurantBranchId': restaurantBranchId,
      'currentStepIndex': currentStepIndex,
      'completedStepIndexes': completedStepIndexes.toList()..sort(),
      'restaurantName': restaurantName,
      'branchName': branchName,
      'area': area,
      'address': address,
      'floorCount': floorCount,
      'selectedTableCapacities': selectedTableCapacities,
      'tableCountsByFloor': [
        for (final counts in tableCountsByFloor)
          <String, dynamic>{'counts': counts},
      ],
    };
  }

  static RestaurantOnboardingDraft? fromFirestore(Object? value) {
    if (value is! Map) return null;
    final data = value.cast<String, dynamic>();
    final restaurantBranchId = (data['restaurantBranchId'] as String? ?? '')
        .trim();
    if (restaurantBranchId.isEmpty) return null;

    final selectedTableCapacities = _intListFromValue(
      data['selectedTableCapacities'],
    );
    final floorCount = _intFromValue(data['floorCount'], 1).clamp(1, 15);
    final rows = _tableCountsFromValue(data['tableCountsByFloor']);
    final normalizedRows = [
      for (var floorIndex = 0; floorIndex < floorCount; floorIndex++)
        _rowForCapacityCount(
          floorIndex < rows.length ? rows[floorIndex] : const <int>[],
          selectedTableCapacities.length,
        ),
    ];

    return RestaurantOnboardingDraft(
      restaurantBranchId: restaurantBranchId,
      currentStepIndex: _intFromValue(data['currentStepIndex'], 0).clamp(0, 3),
      completedStepIndexes: _intListFromValue(
        data['completedStepIndexes'],
      ).where((index) => index >= 0 && index <= 2).toSet(),
      restaurantName: data['restaurantName'] as String? ?? '',
      branchName: data['branchName'] as String? ?? '',
      area: data['area'] as String? ?? '',
      address: data['address'] as String? ?? '',
      floorCount: floorCount,
      selectedTableCapacities: selectedTableCapacities,
      tableCountsByFloor: normalizedRows,
    );
  }
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
    this.onboardingDraft,
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
  final RestaurantOnboardingDraft? onboardingDraft;

  String get displayName => '$restaurantName - $branchName';

  bool get isProvisioningCompleted => onboardingCompleted && branchActive;
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

int _intFromValue(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

List<int> _intListFromValue(Object? value) {
  if (value is! Iterable) return const <int>[];
  return [
    for (final item in value)
      if (_intFromValue(item, -1) >= 0) _intFromValue(item, -1),
  ];
}

List<List<int>> _tableCountsFromValue(Object? value) {
  if (value is! Iterable) return const <List<int>>[];
  return [
    for (final item in value)
      if (item is Map)
        _intListFromValue(item['counts'])
      else if (item is Iterable)
        _intListFromValue(item),
  ];
}

List<int> _rowForCapacityCount(List<int> row, int capacityCount) {
  final normalizedRow = List<int>.from(row, growable: true);
  while (normalizedRow.length < capacityCount) {
    normalizedRow.add(0);
  }
  while (normalizedRow.length > capacityCount) {
    normalizedRow.removeLast();
  }
  return normalizedRow;
}
