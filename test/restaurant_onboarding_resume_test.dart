import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ezq/features/rest_onboarding/data/restaurant_onboarding_repository.dart';
import 'package:ezq/features/rest_onboarding/domain/onboarding_provisioning.dart';
import 'package:ezq/features/rest_onboarding/providers/restaurant_onboarding_controller.dart';

void main() {
  test('loadAdminContext restores persisted onboarding draft', () async {
    final repository = _FakeOnboardingRepository(
      context: RestaurantBranchAdminContext(
        uid: 'admin-1',
        name: 'Admin',
        email: 'admin@example.com',
        phone: '+919999000000',
        restaurantBranchId: 'draft-branch',
        role: 'owner',
        isActive: true,
        onboardingCompleted: false,
        provisioningStatus: 'pending',
        branchActive: true,
        restaurantName: 'Draft Restaurant',
        branchName: 'Main',
        area: 'Indiranagar',
        address: '12th Main',
        slug: 'draft-branch',
        onboardingDraft: const RestaurantOnboardingDraft(
          restaurantBranchId: 'draft-branch',
          currentStepIndex: 2,
          completedStepIndexes: <int>{0, 1},
          restaurantName: 'Draft Restaurant',
          branchName: 'Main',
          area: 'Indiranagar',
          address: '12th Main',
          floorCount: 2,
          selectedTableCapacities: <int>[2, 4],
          tableCountsByFloor: <List<int>>[
            <int>[3, 2],
            <int>[1, 4],
          ],
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(restaurantOnboardingControllerProvider.notifier)
        .loadAdminContext(expectedRestaurantBranchId: 'draft-branch');

    final state = container.read(restaurantOnboardingControllerProvider);
    expect(state.currentStepIndex, 2);
    expect(state.completedStepIndexes, <int>{0, 1});
    expect(state.floorCount, 2);
    expect(state.selectedTableCapacities, <int>[2, 4]);
    expect(state.tableCountsByFloor, <List<int>>[
      <int>[3, 2],
      <int>[1, 4],
    ]);
    expect(state.totalTables, 10);
    expect(state.totalSeats, 32);
  });

  test('saveDraft persists current onboarding state', () async {
    final repository = _FakeOnboardingRepository(
      context: const RestaurantBranchAdminContext(
        uid: 'admin-1',
        name: 'Admin',
        email: 'admin@example.com',
        phone: '+919999000000',
        restaurantBranchId: 'draft-branch',
        role: 'owner',
        isActive: true,
        onboardingCompleted: false,
        provisioningStatus: 'pending',
        branchActive: true,
        restaurantName: 'Draft Restaurant',
        branchName: 'Main',
        area: 'Indiranagar',
        address: '12th Main',
        slug: 'draft-branch',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      restaurantOnboardingControllerProvider.notifier,
    );
    await controller.loadAdminContext(
      expectedRestaurantBranchId: 'draft-branch',
    );
    controller.addTableCapacity(4);
    controller.updateTableCount(0, 0, 5);
    await controller.saveDraft();

    final saved = repository.savedDraft;
    expect(saved, isNotNull);
    expect(saved!.restaurantBranchId, 'draft-branch');
    expect(saved.selectedTableCapacities, <int>[4]);
    expect(saved.tableCountsByFloor, <List<int>>[
      <int>[5],
    ]);
  });

  test(
    'completed onboarding restores read-only Screen 4 from persisted data',
    () async {
      final completionTime = DateTime.utc(2026, 7, 30, 10);
      final repository = _FakeOnboardingRepository(
        context: RestaurantBranchAdminContext(
          uid: 'admin-1',
          name: 'Admin',
          email: 'admin@example.com',
          phone: '+919999000000',
          restaurantBranchId: 'complete-branch',
          role: 'owner',
          isActive: true,
          onboardingCompleted: true,
          adminOnboardingCompleted: true,
          provisioningStatus: 'completed',
          branchActive: true,
          restaurantName: 'Complete Restaurant',
          branchName: 'Main',
          area: 'Indiranagar',
          address: '12th Main',
          slug: 'complete-branch',
          floorCount: 2,
          totalTables: 6,
          totalSeats: 18,
          capacityTypes: const <int>[2, 4],
          tableCountsByFloor: const <List<int>>[
            <int>[2, 1],
            <int>[1, 2],
          ],
          onboardingCompletedAt: completionTime,
          queueUrl: 'https://example.test/customer/complete-branch',
          provisioningFingerprint: 'persisted',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(restaurantOnboardingControllerProvider.notifier)
          .loadAdminContext(expectedRestaurantBranchId: 'complete-branch');

      final state = container.read(restaurantOnboardingControllerProvider);
      expect(state.currentStepIndex, 3);
      expect(state.completedStepIndexes, <int>{0, 1, 2});
      expect(state.lockNavigation, isTrue);
      expect(state.provisioningResult?.createdAt, completionTime);
      expect(state.totalTables, 6);
      expect(state.totalSeats, 18);
      expect(
        state.provisioningProgress.every(
          (step) => step.status == ProvisioningStepStatus.complete,
        ),
        isTrue,
      );
    },
  );

  test(
    'Retry after a failed provisioning attempt succeeds deterministically',
    () async {
      final repository = _FakeOnboardingRepository(
        context: const RestaurantBranchAdminContext(
          uid: 'admin-1',
          name: 'Admin',
          email: 'admin@example.com',
          phone: '+919999000000',
          restaurantBranchId: 'retry-branch',
          role: 'owner',
          isActive: true,
          onboardingCompleted: false,
          provisioningStatus: 'pending',
          branchActive: true,
          restaurantName: 'Retry Restaurant',
          branchName: 'Main',
          area: 'Indiranagar',
          address: '12th Main',
          slug: 'retry-branch',
        ),
        failFirstProvision: true,
      );
      final container = ProviderContainer(
        overrides: [
          restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        restaurantOnboardingControllerProvider.notifier,
      );
      await controller.loadAdminContext(
        expectedRestaurantBranchId: 'retry-branch',
      );
      controller.addTableCapacity(4);
      controller.updateTableCount(0, 0, 2);

      await controller.startProvisioning();
      expect(
        container
            .read(restaurantOnboardingControllerProvider)
            .failedProvisioningStep,
        OnboardingProvisioningStep.createTables,
      );

      await controller.startProvisioning();
      final state = container.read(restaurantOnboardingControllerProvider);
      expect(repository.provisionAttempts, 2);
      expect(state.provisioningResult, isNotNull);
      expect(state.failedProvisioningStep, isNull);
    },
  );
}

class _FakeOnboardingRepository implements RestaurantOnboardingRepository {
  _FakeOnboardingRepository({
    required this.context,
    this.failFirstProvision = false,
  });

  final RestaurantBranchAdminContext? context;
  final bool failFirstProvision;
  RestaurantOnboardingDraft? savedDraft;
  int provisionAttempts = 0;

  @override
  Future<RestaurantBranchAdminContext?> loadAdminContext() async => context;

  @override
  Future<CompletedRestaurantOnboarding?> completedOnboardingForCurrentAdmin() {
    final adminContext = context;
    if (adminContext == null || !adminContext.isProvisioningCompleted) {
      return Future.value(null);
    }
    return Future.value(
      CompletedRestaurantOnboarding(
        restaurantBranchId: adminContext.restaurantBranchId,
      ),
    );
  }

  @override
  Future<void> saveOnboardingDraft(RestaurantOnboardingDraft draft) async {
    savedDraft = draft;
  }

  @override
  Future<RestaurantOnboardingResult> provisionRestaurant({
    required RestaurantOnboardingRequest request,
    required ProvisioningStepCallback onStepStarted,
    required ProvisioningStepCallback onStepCompleted,
  }) async {
    provisionAttempts++;
    if (failFirstProvision && provisionAttempts == 1) {
      onStepStarted(OnboardingProvisioningStep.createTables);
      throw const RestaurantOnboardingFailure(
        step: OnboardingProvisioningStep.createTables,
        message: 'Forced table stage failure',
      );
    }
    for (final step in OnboardingProvisioningStep.values) {
      onStepStarted(step);
      onStepCompleted(step);
    }
    return RestaurantOnboardingResult(
      restaurantBranchId: request.restaurantBranchId,
      createdAt: DateTime.utc(2026, 7, 30, 11),
      adminEmail: context?.email ?? '',
      qrUrl: '/customer/${request.restaurantBranchId}',
    );
  }
}
