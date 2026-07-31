import 'dart:async';

import 'package:ezq/features/rest_onboarding/data/restaurant_onboarding_repository.dart';
import 'package:ezq/features/rest_onboarding/domain/onboarding_provisioning.dart';
import 'package:ezq/features/rest_onboarding/presentation/screens/restaurant_onboarding_screen.dart';
import 'package:ezq/features/rest_onboarding/presentation/widgets/floors_tables_step.dart';
import 'package:ezq/features/rest_onboarding/presentation/widgets/restaurant_details_step.dart';
import 'package:ezq/features/rest_onboarding/presentation/widgets/restaurant_onboarding_wizard_bar.dart';
import 'package:ezq/features/rest_onboarding/presentation/widgets/review_confirm_step.dart';
import 'package:ezq/features/rest_onboarding/providers/restaurant_onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'post-frame deep-link load ignores stale cache and restores Screen 4 only',
    (tester) async {
      final load = Completer<RestaurantBranchAdminContext?>();
      final repository = _SequencedOnboardingRepository([() => load.future]);
      final container = ProviderContainer(
        overrides: [
          restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        restaurantOnboardingControllerProvider.notifier,
      );
      controller.updateRestaurantName('Stale cached restaurant');
      controller.addTableCapacity(12);

      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(RestaurantDetailsStep), findsNothing);
      expect(find.byType(RestaurantOnboardingWizardBar), findsNothing);

      load.complete(_completedContext());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(repository.loadCount, 1);
      expect(find.text('Setup Summary'), findsOneWidget);
      expect(find.text('Provisioning Checklist'), findsOneWidget);
      expect(find.text('View Setup Summary'), findsOneWidget);
      expect(find.text('Manage QR'), findsOneWidget);
      expect(find.text('Go to Dashboard'), findsOneWidget);
      expect(find.text('Persisted Restaurant'), findsWidgets);
      expect(find.text('/customer/completed-branch'), findsOneWidget);
      expect(find.text('Stale cached restaurant'), findsNothing);
      expect(find.text('Draft Restaurant Must Be Ignored'), findsNothing);
      expect(find.byType(RestaurantOnboardingWizardBar), findsNothing);
      expect(find.byType(RestaurantDetailsStep), findsNothing);
      expect(find.byType(FloorsTablesStep), findsNothing);
      expect(find.byType(ReviewConfirmStep), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('fresh incomplete onboarding still restores Screen 1', (
    tester,
  ) async {
    final repository = _SequencedOnboardingRepository([
      () async => _freshContext(),
    ]);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(RestaurantDetailsStep), findsOneWidget);
    expect(find.byType(RestaurantOnboardingWizardBar), findsOneWidget);
  });

  testWidgets(
    'missing canonical Step 1 field names its Firestore path and disables Continue',
    (tester) async {
      final repository = _SequencedOnboardingRepository([
        () async => _freshContextMissingArea(),
      ]);
      final container = ProviderContainer(
        overrides: [
          restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Required Firestore data is missing'), findsOneWidget);
      expect(
        find.text(
          '• Missing restaurantBranches/completed-branch field "area".',
        ),
        findsWidgets,
      );
      expect(find.text('Not specified'), findsNothing);
      expect(
        container
            .read(restaurantOnboardingControllerProvider)
            .step1ValidationReasons,
        contains('Area'),
      );
      expect(
        container.read(restaurantOnboardingControllerProvider).isStep1Valid,
        isFalse,
      );
    },
  );

  testWidgets('load failure resets loading and Retry reconstructs summary', (
    tester,
  ) async {
    final repository = _SequencedOnboardingRepository([
      () async => throw StateError('Firestore unavailable'),
      () async => _completedContext(),
    ]);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Unable to Load Onboarding'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Go to Dashboard'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.loadCount, 2);
    expect(find.text('Provisioning Checklist'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('incomplete completed Firestore data never falls back to forms', (
    tester,
  ) async {
    final repository = _SequencedOnboardingRepository([
      () async => _incompleteCompletedContext(),
    ]);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Unable to Load Onboarding'), findsOneWidget);
    expect(
      find.textContaining('Completed onboarding data is incomplete'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Go to Dashboard'), findsOneWidget);
    expect(find.byType(RestaurantOnboardingWizardBar), findsNothing);
    expect(find.byType(RestaurantDetailsStep), findsNothing);
    expect(find.byType(FloorsTablesStep), findsNothing);
    expect(find.byType(ReviewConfirmStep), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('completed summary allows route back navigation', (tester) async {
    final repository = _SequencedOnboardingRepository([
      () async => _completedContext(),
    ]);
    final router = _router(initialLocation: '/origin');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('Open onboarding summary'));
    await tester.pumpAndSettle();
    expect(find.text('Provisioning Checklist'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Origin'), findsOneWidget);
  });

  testWidgets('error action navigates to the branch dashboard route', (
    tester,
  ) async {
    final repository = _SequencedOnboardingRepository([
      () async => throw StateError('Firestore unavailable'),
    ]);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go to Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard completed-branch'), findsOneWidget);
  });
}

GoRouter _router({String? initialLocation}) {
  return GoRouter(
    initialLocation:
        initialLocation ?? '/admin/completed-branch/register/onboarding',
    routes: [
      GoRoute(
        path: '/origin',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              const Text('Origin'),
              FilledButton(
                onPressed: () =>
                    context.push('/admin/completed-branch/register/onboarding'),
                child: const Text('Open onboarding summary'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/admin/:restaurantBranchId/register/onboarding',
        builder: (context, state) => const RestaurantOnboardingScreen(),
      ),
      GoRoute(
        path: '/admin/:restaurantBranchId/dashboard',
        builder: (context, state) => Scaffold(
          body: Text('Dashboard ${state.pathParameters['restaurantBranchId']}'),
        ),
      ),
    ],
  );
}

RestaurantBranchAdminContext _completedContext() {
  return RestaurantBranchAdminContext(
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
    restaurantName: 'Persisted Restaurant',
    branchName: 'Persisted Branch',
    area: 'Indiranagar',
    address: '12th Main',
    slug: 'completed-branch',
    onboardingDraft: const RestaurantOnboardingDraft(
      restaurantBranchId: 'completed-branch',
      currentStepIndex: 0,
      completedStepIndexes: <int>{},
      restaurantName: 'Draft Restaurant Must Be Ignored',
      branchName: 'Draft Branch',
      area: 'Draft Area',
      address: 'Draft Address',
      floorCount: 1,
      selectedTableCapacities: <int>[12],
      tableCountsByFloor: <List<int>>[
        <int>[99],
      ],
    ),
    floorCount: 3,
    selectedTableCapacities: const <int>[2, 4, 8],
    totalTables: 14,
    totalSeats: 68,
    createdAt: DateTime.utc(2026, 7, 28),
  );
}

RestaurantBranchAdminContext _freshContext() {
  return const RestaurantBranchAdminContext(
    uid: 'admin-1',
    name: 'Admin',
    email: 'admin@example.com',
    phone: '+919999000000',
    restaurantBranchId: 'completed-branch',
    role: 'owner',
    isActive: true,
    onboardingCompleted: false,
    provisioningStatus: 'pending',
    branchActive: true,
    restaurantName: 'Fresh Restaurant',
    branchName: 'Fresh Branch',
    area: 'Indiranagar',
    address: '12th Main',
    slug: 'completed-branch',
  );
}

RestaurantBranchAdminContext _freshContextMissingArea() {
  return const RestaurantBranchAdminContext(
    uid: 'admin-1',
    name: 'Admin',
    email: 'admin@example.com',
    phone: '+919999000000',
    restaurantBranchId: 'completed-branch',
    role: 'owner',
    isActive: true,
    onboardingCompleted: false,
    provisioningStatus: 'pending',
    branchActive: true,
    restaurantName: 'Fresh Restaurant',
    branchName: 'Fresh Branch',
    area: '',
    address: '12th Main',
    slug: 'completed-branch',
  );
}

RestaurantBranchAdminContext _incompleteCompletedContext() {
  return const RestaurantBranchAdminContext(
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
    restaurantName: 'Persisted Restaurant',
    branchName: 'Persisted Branch',
    area: 'Indiranagar',
    address: '12th Main',
    slug: 'completed-branch',
  );
}

class _SequencedOnboardingRepository implements RestaurantOnboardingRepository {
  _SequencedOnboardingRepository(this._loads);

  final List<Future<RestaurantBranchAdminContext?> Function()> _loads;
  int loadCount = 0;

  @override
  Future<RestaurantBranchAdminContext?> loadAdminContext() {
    final index = loadCount++;
    return _loads[index]();
  }

  @override
  Future<CompletedRestaurantOnboarding?>
  completedOnboardingForCurrentAdmin() async {
    return null;
  }

  @override
  Future<RestaurantOnboardingResult> provisionRestaurant({
    required RestaurantOnboardingRequest request,
    required ProvisioningStepCallback onStepStarted,
    required ProvisioningStepCallback onStepCompleted,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveOnboardingDraft(RestaurantOnboardingDraft draft) async {}
}
