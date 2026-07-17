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
}

class _FakeOnboardingRepository implements RestaurantOnboardingRepository {
  _FakeOnboardingRepository({required this.context});

  final RestaurantBranchAdminContext? context;
  RestaurantOnboardingDraft? savedDraft;

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
  }) {
    throw UnimplementedError();
  }
}
