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
        restaurantName: 'Canonical Restaurant',
        branchName: 'Canonical Branch',
        area: 'Canonical Area',
        address: 'Canonical Address',
        slug: 'draft-branch',
        onboardingDraft: const RestaurantOnboardingDraft(
          restaurantBranchId: 'draft-branch',
          currentStepIndex: 2,
          completedStepIndexes: <int>{0, 1},
          restaurantName: '',
          branchName: 'Stale Draft Branch',
          area: '',
          address: 'Stale Draft Address',
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
    expect(state.restaurantName, 'Canonical Restaurant');
    expect(state.branchName, 'Canonical Branch');
    expect(state.area, 'Canonical Area');
    expect(state.address, 'Canonical Address');
    expect(state.isStep1Valid, isTrue);
    expect(state.floorCount, 2);
    expect(state.selectedTableCapacities, <int>[2, 4]);
    expect(state.tableCountsByFloor, <List<int>>[
      <int>[3, 2],
      <int>[1, 4],
    ]);
    expect(state.totalTables, 10);
    expect(state.totalSeats, 32);
  });

  test('Step 1 validation reports every required field', () {
    var state = RestaurantOnboardingState.initial().copyWith(
      restaurantBranchId: 'fresh-branch',
      adminName: 'Admin',
      adminEmail: 'admin@example.com',
      adminPhone: '+919999000000',
      restaurantName: 'Fresh Restaurant',
      branchName: 'Main',
    );

    expect(state.step1ValidationRules, <String, bool>{
      'Restaurant Branch ID': true,
      'Admin Context Loaded': true,
      'Admin Name': true,
      'Email': true,
      'Phone': true,
      'Restaurant': true,
      'Branch': true,
      'Area': false,
      'Address': false,
    });
    expect(state.step1ValidationReasons, <String>['Area', 'Address']);
    expect(state.isStep1Valid, isFalse);

    state = state.copyWith(area: 'Indiranagar', address: '12th Main');
    expect(state.step1ValidationReasons, isEmpty);
    expect(state.isStep1Valid, isTrue);
  });

  test(
    'completed provisioning status cannot restore an incomplete branch',
    () async {
      final repository = _FakeOnboardingRepository(
        context: const RestaurantBranchAdminContext(
          uid: 'admin-1',
          name: 'Admin',
          email: 'admin@example.com',
          phone: '+919999000000',
          restaurantBranchId: 'broken-branch',
          role: 'owner',
          isActive: true,
          onboardingCompleted: false,
          adminOnboardingCompleted: true,
          provisioningStatus: 'completed',
          branchActive: true,
          restaurantName: 'Broken Restaurant',
          branchName: 'Main',
          area: 'Indiranagar',
          address: '12th Main',
          slug: 'broken-branch',
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
          .loadAdminContext(expectedRestaurantBranchId: 'broken-branch');

      final state = container.read(restaurantOnboardingControllerProvider);
      expect(
        state.adminContextError,
        contains('Inconsistent onboarding state'),
      );
      expect(state.currentStepIndex, 0);
      expect(state.isStep1Valid, isFalse);
    },
  );

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

  test('completed onboarding restores locked Screen 4 summary state', () async {
    final repository = _FakeOnboardingRepository(
      context: RestaurantBranchAdminContext(
        uid: 'admin-1',
        name: 'Admin',
        email: 'admin@example.com',
        phone: '+919999000000',
        restaurantBranchId: 'completed-branch',
        role: 'owner',
        isActive: true,
        onboardingCompleted: true,
        provisioningStatus: 'completed',
        branchActive: true,
        restaurantName: 'Completed Restaurant',
        branchName: 'Main',
        area: 'Indiranagar',
        address: '12th Main',
        slug: 'completed-branch',
        floorCount: 3,
        selectedTableCapacities: const <int>[2, 4, 8],
        totalTables: 14,
        totalSeats: 68,
        createdAt: DateTime.utc(2026, 7, 28),
        queueUrl:
            'https://ezq-dev-cubiquitous.web.app/customer/completed-branch',
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
      expectedRestaurantBranchId: 'completed-branch',
    );

    var state = container.read(restaurantOnboardingControllerProvider);
    expect(state.currentStepIndex, 3);
    expect(state.completedStepIndexes, <int>{0, 1, 2});
    expect(state.enabledStepIndexes, <int>{3});
    expect(state.lockNavigation, isTrue);
    expect(state.floorCount, 3);
    expect(state.selectedTableCapacities, <int>[2, 4, 8]);
    expect(state.totalTables, 14);
    expect(state.totalSeats, 68);
    expect(state.provisioningResult?.restaurantBranchId, 'completed-branch');
    expect(
      state.provisioningResult?.qrUrl,
      'https://ezq-dev-cubiquitous.web.app/customer/completed-branch',
    );
    expect(
      state.provisioningProgress.every(
        (step) => step.status == ProvisioningStepStatus.complete,
      ),
      isTrue,
    );

    controller.selectStep(0);
    controller.backFromStep4();
    await controller.saveDraft();
    state = container.read(restaurantOnboardingControllerProvider);
    expect(state.currentStepIndex, 3);
    expect(repository.savedDraft, isNull);
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
