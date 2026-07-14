import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/restaurant_onboarding_repository.dart';
import '../domain/onboarding_provisioning.dart';

final restaurantOnboardingRepositoryProvider =
    Provider<RestaurantOnboardingRepository>((ref) {
      return FirebaseRestaurantOnboardingRepository();
    });

final restaurantOnboardingControllerProvider =
    NotifierProvider<RestaurantOnboardingController, RestaurantOnboardingState>(
      RestaurantOnboardingController.new,
    );

RestaurantBranchAdminContext? temporaryAdminContext;

bool duplicateRestaurantBranch(String restaurant, String branch) {
  return false;
}

class RestaurantOnboardingState {
  const RestaurantOnboardingState({
    required this.currentStepIndex,
    required this.completedStepIndexes,
    required this.restaurantBranchId,
    required this.adminName,
    required this.adminEmail,
    required this.adminPhone,
    required this.restaurantName,
    required this.branchName,
    required this.area,
    required this.address,
    required this.isLoadingAdminContext,
    required this.adminContextError,
    required this.showRestaurantError,
    required this.showBranchError,
    required this.floorCount,
    required this.selectedTableCapacities,
    required this.tableCountsByFloor,
    required this.showStep2ValidationError,
    required this.provisioningProgress,
    required this.isProvisioning,
    required this.provisioningResult,
    required this.failedProvisioningStep,
    required this.provisioningErrorMessage,
  });

  factory RestaurantOnboardingState.initial() {
    return RestaurantOnboardingState(
      currentStepIndex: 0,
      completedStepIndexes: const <int>{},
      restaurantBranchId: '',
      adminName: '',
      adminEmail: '',
      adminPhone: '',
      restaurantName: '',
      branchName: '',
      area: '',
      address: '',
      isLoadingAdminContext: false,
      adminContextError: null,
      showRestaurantError: false,
      showBranchError: false,
      floorCount: 1,
      selectedTableCapacities: const <int>[],
      tableCountsByFloor: const <List<int>>[<int>[]],
      showStep2ValidationError: false,
      provisioningProgress: initialProvisioningProgress(),
      isProvisioning: false,
      provisioningResult: null,
      failedProvisioningStep: null,
      provisioningErrorMessage: null,
    );
  }

  final int currentStepIndex;
  final Set<int> completedStepIndexes;
  final String restaurantBranchId;
  final String adminName;
  final String adminEmail;
  final String adminPhone;
  final String restaurantName;
  final String branchName;
  final String area;
  final String address;
  final bool isLoadingAdminContext;
  final String? adminContextError;
  final bool showRestaurantError;
  final bool showBranchError;
  final int floorCount;
  final List<int> selectedTableCapacities;
  final List<List<int>> tableCountsByFloor;
  final bool showStep2ValidationError;
  final List<ProvisioningStepProgress> provisioningProgress;
  final bool isProvisioning;
  final RestaurantOnboardingResult? provisioningResult;
  final OnboardingProvisioningStep? failedProvisioningStep;
  final String? provisioningErrorMessage;

  String get trimmedRestaurantName => restaurantName.trim();

  String get trimmedBranchName => branchName.trim();

  String get trimmedArea => area.trim();

  bool get restaurantHasValidLength {
    return trimmedRestaurantName.length >= 3 &&
        trimmedRestaurantName.length <= 100;
  }

  bool get branchHasValidLength {
    return trimmedBranchName.length >= 2 && trimmedBranchName.length <= 60;
  }

  bool get hasDuplicateRestaurantBranch {
    return duplicateRestaurantBranch(trimmedRestaurantName, trimmedBranchName);
  }

  bool get isStep1Valid =>
      restaurantBranchId.trim().isNotEmpty &&
      adminContextError == null &&
      !isLoadingAdminContext &&
      restaurantName.trim().isNotEmpty &&
      branchName.trim().isNotEmpty;

  int get totalTables {
    return tableCountsByFloor.fold<int>(
      0,
      (total, floorCounts) =>
          total + floorCounts.fold<int>(0, (sum, count) => sum + count),
    );
  }

  int get totalSeats {
    var seats = 0;
    for (final floorCounts in tableCountsByFloor) {
      for (var index = 0; index < selectedTableCapacities.length; index++) {
        final tableCount = index < floorCounts.length ? floorCounts[index] : 0;
        seats += tableCount * selectedTableCapacities[index];
      }
    }
    return seats;
  }

  bool get isStep2Valid =>
      selectedTableCapacities.isNotEmpty && totalTables > 0;

  bool get lockNavigation => isProvisioning || provisioningResult != null;

  Set<int> get enabledStepIndexes {
    if (lockNavigation) return <int>{3};
    return <int>{
      0,
      if (isStep1Valid || completedStepIndexes.contains(0)) 1,
      if (isStep2Valid || completedStepIndexes.contains(1)) 2,
      if (completedStepIndexes.contains(2)) 3,
    };
  }

  int get provisioningPercent {
    final completed = provisioningProgress
        .where((step) => step.status == ProvisioningStepStatus.complete)
        .length;
    return ((provisioningProgress.isEmpty
                ? 0
                : completed / provisioningProgress.length) *
            100)
        .round();
  }

  double get provisioningProgressValue => provisioningPercent / 100;

  String get currentProvisioningStepLabel {
    final running = provisioningProgress.where(
      (step) => step.status == ProvisioningStepStatus.running,
    );
    if (running.isNotEmpty) return running.first.step.label;
    final pending = provisioningProgress.where(
      (step) => step.status == ProvisioningStepStatus.pending,
    );
    if (pending.isNotEmpty) return pending.first.step.label;
    return 'Finalizing';
  }

  String get estimatedRemainingTimeLabel {
    final remaining = provisioningProgress
        .where((step) => step.status != ProvisioningStepStatus.complete)
        .length;
    if (remaining == 0) return 'Almost done';
    return '~${remaining * 3}s remaining';
  }

  String? get restaurantErrorText {
    if (!showRestaurantError) return null;
    if (trimmedRestaurantName.isEmpty) return 'Restaurant name is required';
    if (trimmedRestaurantName.length < 3) {
      return 'Restaurant name must be at least 3 characters';
    }
    if (trimmedRestaurantName.length > 100) {
      return 'Restaurant name must be 100 characters or fewer';
    }
    if (branchHasValidLength && hasDuplicateRestaurantBranch) {
      return 'Restaurant and branch already exist';
    }
    return null;
  }

  String? get branchErrorText {
    if (!showBranchError) return null;
    if (trimmedBranchName.isEmpty) return 'Branch name is required';
    if (trimmedBranchName.length < 2) {
      return 'Branch name must be at least 2 characters';
    }
    if (trimmedBranchName.length > 60) {
      return 'Branch name must be 60 characters or fewer';
    }
    if (restaurantHasValidLength && hasDuplicateRestaurantBranch) {
      return 'Restaurant and branch already exist';
    }
    return null;
  }

  RestaurantOnboardingState copyWith({
    int? currentStepIndex,
    Set<int>? completedStepIndexes,
    String? restaurantBranchId,
    String? adminName,
    String? adminEmail,
    String? adminPhone,
    String? restaurantName,
    String? branchName,
    String? area,
    String? address,
    bool? isLoadingAdminContext,
    String? adminContextError,
    bool clearAdminContextError = false,
    bool? showRestaurantError,
    bool? showBranchError,
    int? floorCount,
    List<int>? selectedTableCapacities,
    List<List<int>>? tableCountsByFloor,
    bool? showStep2ValidationError,
    List<ProvisioningStepProgress>? provisioningProgress,
    bool? isProvisioning,
    RestaurantOnboardingResult? provisioningResult,
    bool clearProvisioningResult = false,
    OnboardingProvisioningStep? failedProvisioningStep,
    bool clearFailedProvisioningStep = false,
    String? provisioningErrorMessage,
    bool clearProvisioningErrorMessage = false,
  }) {
    return RestaurantOnboardingState(
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      completedStepIndexes: completedStepIndexes ?? this.completedStepIndexes,
      restaurantBranchId: restaurantBranchId ?? this.restaurantBranchId,
      adminName: adminName ?? this.adminName,
      adminEmail: adminEmail ?? this.adminEmail,
      adminPhone: adminPhone ?? this.adminPhone,
      restaurantName: restaurantName ?? this.restaurantName,
      branchName: branchName ?? this.branchName,
      area: area ?? this.area,
      address: address ?? this.address,
      isLoadingAdminContext:
          isLoadingAdminContext ?? this.isLoadingAdminContext,
      adminContextError: clearAdminContextError
          ? null
          : adminContextError ?? this.adminContextError,
      showRestaurantError: showRestaurantError ?? this.showRestaurantError,
      showBranchError: showBranchError ?? this.showBranchError,
      floorCount: floorCount ?? this.floorCount,
      selectedTableCapacities:
          selectedTableCapacities ?? this.selectedTableCapacities,
      tableCountsByFloor: tableCountsByFloor ?? this.tableCountsByFloor,
      showStep2ValidationError:
          showStep2ValidationError ?? this.showStep2ValidationError,
      provisioningProgress: provisioningProgress ?? this.provisioningProgress,
      isProvisioning: isProvisioning ?? this.isProvisioning,
      provisioningResult: clearProvisioningResult
          ? null
          : provisioningResult ?? this.provisioningResult,
      failedProvisioningStep: clearFailedProvisioningStep
          ? null
          : failedProvisioningStep ?? this.failedProvisioningStep,
      provisioningErrorMessage: clearProvisioningErrorMessage
          ? null
          : provisioningErrorMessage ?? this.provisioningErrorMessage,
    );
  }

  RestaurantOnboardingRequest toProvisioningRequest() {
    assert(debugAssertTableConfigurationInvariant());
    return RestaurantOnboardingRequest(
      restaurantBranchId: restaurantBranchId,
      restaurantName: trimmedRestaurantName,
      branchName: trimmedBranchName,
      area: trimmedArea,
      address: address.trim(),
      floorCount: floorCount,
      selectedTableCapacities: List<int>.unmodifiable(selectedTableCapacities),
      tableCountsByFloor: List<List<int>>.unmodifiable(
        tableCountsByFloor.map((counts) => List<int>.unmodifiable(counts)),
      ),
      totalTables: totalTables,
      totalSeats: totalSeats,
    );
  }

  String setupSummaryText(RestaurantOnboardingResult result) {
    return [
      'EZQ Restaurant Onboarding Setup Summary',
      '',
      'Restaurant: $trimmedRestaurantName',
      'Branch: $trimmedBranchName',
      'Restaurant Branch ID: ${result.restaurantBranchId}',
      'Admin Email: ${result.adminEmail}',
      'Floors: $floorCount',
      'Capacity Types: ${selectedTableCapacities.map((capacity) => '$capacity Top').join(', ')}',
      'Tables: $totalTables',
      'Seats: $totalSeats',
      'Creation Timestamp: ${result.createdAt.toIso8601String()}',
      'QR URL: ${result.qrUrl}',
    ].join('\n');
  }

  bool debugAssertTableConfigurationInvariant() {
    assert(() {
      assert(
        tableCountsByFloor.length == floorCount,
        'Expected $floorCount floor rows, found ${tableCountsByFloor.length}.',
      );
      assert(
        tableCountsByFloor.every(
          (row) => row.length == selectedTableCapacities.length,
        ),
        'Every floor count row must match selected capacity count. '
        'Capacities: ${selectedTableCapacities.length}, '
        'row lengths: ${tableCountsByFloor.map((row) => row.length).toList()}.',
      );
      assert(
        selectedTableCapacities.toSet().length ==
            selectedTableCapacities.length,
        'Selected table capacities must be unique.',
      );
      for (var index = 1; index < selectedTableCapacities.length; index++) {
        assert(
          selectedTableCapacities[index - 1] < selectedTableCapacities[index],
          'Selected table capacities must remain sorted ascending.',
        );
      }
      return true;
    }());
    return true;
  }
}

class RestaurantOnboardingController
    extends Notifier<RestaurantOnboardingState> {
  @override
  RestaurantOnboardingState build() {
    return RestaurantOnboardingState.initial();
  }

  Future<CompletedRestaurantOnboarding?>
  completedOnboardingForCurrentAdmin() async {
    debugPrint(
      '[ONBOARDING_CONTROLLER] ENTER completedOnboardingForCurrentAdmin',
    );
    debugPrint(
      '[ONBOARDING_CONTROLLER] BEFORE await repository.completedOnboardingForCurrentAdmin',
    );
    final completion = await ref
        .read(restaurantOnboardingRepositoryProvider)
        .completedOnboardingForCurrentAdmin();
    debugPrint(
      '[ONBOARDING_CONTROLLER] AFTER await repository.completedOnboardingForCurrentAdmin '
      'completion=${completion?.restaurantBranchId ?? 'null'}',
    );
    debugPrint(
      '[ONBOARDING_CONTROLLER] EXIT completedOnboardingForCurrentAdmin',
    );
    return completion;
  }

  Future<void> loadAdminContext({String? expectedRestaurantBranchId}) async {
    debugPrint(
      '[ONBOARDING_CONTROLLER] ENTER loadAdminContext '
      'expectedRestaurantBranchId=${expectedRestaurantBranchId ?? ''}',
    );
    debugPrint('[ONBOARDING_STATE] Loading=true');
    state = state.copyWith(
      isLoadingAdminContext: true,
      restaurantBranchId: '',
      adminName: '',
      adminEmail: '',
      adminPhone: '',
      restaurantName: '',
      branchName: '',
      area: '',
      address: '',
      clearAdminContextError: true,
    );

    try {
      debugPrint(
        '[ONBOARDING_CONTROLLER] BEFORE await repository.loadAdminContext',
      );
      final context = await ref
          .read(restaurantOnboardingRepositoryProvider)
          .loadAdminContext()
          .timeout(const Duration(seconds: 12));
      debugPrint(
        '[ONBOARDING_CONTROLLER] AFTER await repository.loadAdminContext '
        'contextRestaurantBranchId=${context?.restaurantBranchId ?? 'null'}',
      );
      if (context == null) {
        debugPrint('[ONBOARDING_STATE] Loading=false reason=null-context');
        state = state.copyWith(
          isLoadingAdminContext: false,
          adminContextError:
              'Admin mapping was not found. Please sign in again.',
        );
        debugPrint(
          '[ONBOARDING_CONTROLLER] EXIT loadAdminContext null context',
        );
        return;
      }
      if (!context.isActive) {
        debugPrint('[ONBOARDING_STATE] Loading=false reason=inactive-admin');
        state = state.copyWith(
          isLoadingAdminContext: false,
          adminContextError:
              'Admin account is inactive. Contact your EZQ administrator.',
        );
        debugPrint(
          '[ONBOARDING_CONTROLLER] EXIT loadAdminContext inactive admin',
        );
        return;
      }
      final expectedBranch = expectedRestaurantBranchId?.trim() ?? '';
      if (expectedBranch.isNotEmpty &&
          context.restaurantBranchId != expectedBranch) {
        debugPrint('[ONBOARDING_STATE] Loading=false reason=branch-mismatch');
        state = state.copyWith(
          isLoadingAdminContext: false,
          adminContextError:
              'This admin is mapped to ${context.restaurantBranchId}, not $expectedBranch.',
        );
        debugPrint(
          '[ONBOARDING_CONTROLLER] EXIT loadAdminContext branch mismatch '
          'actual=${context.restaurantBranchId} expected=$expectedBranch',
        );
        return;
      }

      debugPrint('[ONBOARDING_STATE] Loading=false reason=success');
      state = state.copyWith(
        restaurantBranchId: context.restaurantBranchId,
        adminName: context.name,
        adminEmail: context.email,
        adminPhone: context.phone,
        restaurantName: context.restaurantName,
        branchName: context.branchName,
        area: context.area,
        address: context.address,
        isLoadingAdminContext: false,
        clearAdminContextError: true,
      );
      debugPrint('[ONBOARDING_CONTROLLER] EXIT loadAdminContext success');
    } catch (error, stackTrace) {
      debugPrint(
        '[ONBOARDING_CONTROLLER] loadAdminContext failed: $error\n'
        '$stackTrace',
      );
      debugPrint('[ONBOARDING_STATE] Loading=false reason=error');
      state = state.copyWith(
        isLoadingAdminContext: false,
        adminContextError: 'Unable to load onboarding details: $error',
      );
      debugPrint('[ONBOARDING_CONTROLLER] EXIT loadAdminContext error');
    }
  }

  void updateRestaurantName(String value) {
    state = state.copyWith(
      restaurantName: value,
      showRestaurantError: state.showRestaurantError || value.isNotEmpty,
    );
  }

  void updateBranchName(String value) {
    state = state.copyWith(
      branchName: value,
      showBranchError: state.showBranchError || value.isNotEmpty,
    );
  }

  void updateArea(String value) {
    state = state.copyWith(area: value);
  }

  void selectStep(int index) {
    if (state.lockNavigation) return;
    if (!state.enabledStepIndexes.contains(index)) return;
    final completed = Set<int>.from(state.completedStepIndexes);
    if (index > state.currentStepIndex) {
      for (var i = state.currentStepIndex; i < index; i++) {
        completed.add(i);
      }
    }
    state = state.copyWith(
      currentStepIndex: index,
      completedStepIndexes: completed,
    );
  }

  void continueFromStep1() {
    state = state.copyWith(showRestaurantError: true, showBranchError: true);
    if (!state.isStep1Valid) return;
    selectStep(1);
  }

  void backFromStep2() {
    state = state.copyWith(currentStepIndex: 0);
  }

  void continueFromStep2() {
    state = state.copyWith(showStep2ValidationError: true);
    if (!state.isStep2Valid) return;
    selectStep(2);
  }

  void backFromStep3() {
    state = state.copyWith(currentStepIndex: 1);
  }

  void backFromStep4() {
    if (state.isProvisioning) return;
    state = state.copyWith(currentStepIndex: 2);
  }

  void backToReviewFromFailure() {
    if (state.isProvisioning) return;
    state = state.copyWith(currentStepIndex: 2);
  }

  void updateFloorCount(int value) {
    final nextFloorCount = value.clamp(1, 15);
    state = _withSynchronizedTableConfiguration(
      state.copyWith(floorCount: nextFloorCount),
    );
  }

  void addTableCapacity(int capacity) {
    if (state.selectedTableCapacities.contains(capacity)) return;
    final previousCapacityCount = state.selectedTableCapacities.length;
    final nextCapacities = List<int>.from(state.selectedTableCapacities);
    var insertIndex = 0;
    while (insertIndex < nextCapacities.length &&
        nextCapacities[insertIndex] < capacity) {
      insertIndex++;
    }
    nextCapacities.insert(insertIndex, capacity);

    final nextRows = [
      for (final row in state.tableCountsByFloor)
        _rowForCapacityCount(row, previousCapacityCount)
          ..insert(insertIndex, 0),
    ];

    state = _withSynchronizedTableConfiguration(
      state.copyWith(
        selectedTableCapacities: nextCapacities,
        tableCountsByFloor: nextRows,
      ),
    );
  }

  void removeTableCapacity(int capacity) {
    final removeIndex = state.selectedTableCapacities.indexOf(capacity);
    if (removeIndex == -1) return;
    final previousCapacityCount = state.selectedTableCapacities.length;
    final nextCapacities = List<int>.from(state.selectedTableCapacities)
      ..removeAt(removeIndex);

    final nextRows = [
      for (final row in state.tableCountsByFloor)
        _rowForCapacityCount(row, previousCapacityCount)..removeAt(removeIndex),
    ];

    state = _withSynchronizedTableConfiguration(
      state.copyWith(
        selectedTableCapacities: nextCapacities,
        tableCountsByFloor: nextRows,
        showStep2ValidationError: state.isStep2Valid
            ? false
            : state.showStep2ValidationError,
      ),
    );
  }

  void updateTableCount(int floorIndex, int tableTypeIndex, int value) {
    if (floorIndex < 0 || floorIndex >= state.tableCountsByFloor.length) {
      return;
    }
    final synchronized = _withSynchronizedTableConfiguration(state);
    if (tableTypeIndex < 0 ||
        tableTypeIndex >= synchronized.selectedTableCapacities.length) {
      state = synchronized;
      return;
    }
    final nextRows = [
      for (
        var index = 0;
        index < synchronized.tableCountsByFloor.length;
        index++
      )
        if (index == floorIndex)
          [
            for (
              var tableType = 0;
              tableType < synchronized.tableCountsByFloor[index].length;
              tableType++
            )
              tableType == tableTypeIndex
                  ? value.clamp(0, 50)
                  : synchronized.tableCountsByFloor[index][tableType],
          ]
        else
          List<int>.from(synchronized.tableCountsByFloor[index]),
    ];

    state = synchronized.copyWith(
      tableCountsByFloor: nextRows,
      showStep2ValidationError: synchronized.isStep2Valid
          ? false
          : synchronized.showStep2ValidationError,
    );
    assert(state.debugAssertTableConfigurationInvariant());
  }

  Future<void> startProvisioning() async {
    if (state.isProvisioning) return;
    final request = state.toProvisioningRequest();
    state = state.copyWith(
      currentStepIndex: 3,
      completedStepIndexes: <int>{0, 1, 2},
      isProvisioning: true,
      clearProvisioningResult: true,
      clearFailedProvisioningStep: true,
      clearProvisioningErrorMessage: true,
      provisioningProgress: initialProvisioningProgress(),
    );

    try {
      final result = await ref
          .read(restaurantOnboardingRepositoryProvider)
          .provisionRestaurant(
            request: request,
            onStepStarted: _markProvisioningStepRunning,
            onStepCompleted: _markProvisioningStepComplete,
          )
          .timeout(const Duration(seconds: 45));
      state = state.copyWith(isProvisioning: false, provisioningResult: result);
    } on RestaurantOnboardingFailure catch (error) {
      state = state.copyWith(
        isProvisioning: false,
        failedProvisioningStep: error.step,
        provisioningErrorMessage: error.message,
        provisioningProgress: updateProvisioningProgress(
          state.provisioningProgress,
          error.step,
          ProvisioningStepStatus.failed,
        ),
      );
    } catch (error) {
      const fallbackStep = OnboardingProvisioningStep.updateAdmin;
      state = state.copyWith(
        isProvisioning: false,
        failedProvisioningStep: fallbackStep,
        provisioningErrorMessage: error.toString(),
        provisioningProgress: updateProvisioningProgress(
          state.provisioningProgress,
          fallbackStep,
          ProvisioningStepStatus.failed,
        ),
      );
    }
  }

  void _markProvisioningStepRunning(OnboardingProvisioningStep step) {
    state = state.copyWith(
      provisioningProgress: updateProvisioningProgress(
        state.provisioningProgress,
        step,
        ProvisioningStepStatus.running,
      ),
    );
  }

  void _markProvisioningStepComplete(OnboardingProvisioningStep step) {
    state = state.copyWith(
      provisioningProgress: updateProvisioningProgress(
        state.provisioningProgress,
        step,
        ProvisioningStepStatus.complete,
      ),
    );
  }

  RestaurantOnboardingState _withSynchronizedTableConfiguration(
    RestaurantOnboardingState source,
  ) {
    final nextRows = [
      for (var floorIndex = 0; floorIndex < source.floorCount; floorIndex++)
        _rowForCapacityCount(
          floorIndex < source.tableCountsByFloor.length
              ? source.tableCountsByFloor[floorIndex]
              : const <int>[],
          source.selectedTableCapacities.length,
        ),
    ];
    final nextState = source.copyWith(tableCountsByFloor: nextRows);
    assert(nextState.debugAssertTableConfigurationInvariant());
    return nextState;
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
}

List<ProvisioningStepProgress> initialProvisioningProgress() {
  return [
    for (final step in OnboardingProvisioningStep.values)
      ProvisioningStepProgress(
        step: step,
        status: ProvisioningStepStatus.pending,
      ),
  ];
}

List<ProvisioningStepProgress> updateProvisioningProgress(
  List<ProvisioningStepProgress> progress,
  OnboardingProvisioningStep step,
  ProvisioningStepStatus status,
) {
  return [
    for (final item in progress)
      if (item.step == step) item.copyWith(status: status) else item,
  ];
}
