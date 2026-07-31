import 'package:ezq/features/rest_onboarding/data/restaurant_onboarding_repository.dart';
import 'package:ezq/features/rest_onboarding/domain/onboarding_provisioning.dart';
import 'package:ezq/features/rest_onboarding/presentation/screens/restaurant_onboarding_screen.dart';
import 'package:ezq/features/rest_onboarding/providers/restaurant_onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'completed deep link restores Screen 4 without a lifecycle violation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _ScreenRepository(
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
          floorCount: 1,
          totalTables: 2,
          totalSeats: 8,
          capacityTypes: const <int>[4],
          tableCountsByFloor: const <List<int>>[
            <int>[2],
          ],
          onboardingCompletedAt: DateTime.utc(2026, 7, 30),
          queueUrl: 'https://example.test/customer/complete-branch',
          provisioningFingerprint: 'persisted',
        ),
      );

      await _pumpOnboarding(tester, repository);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Setup Summary'), findsOneWidget);
      expect(find.text('Provisioning Checklist'), findsNothing);
      expect(find.text('View Setup Summary'), findsNothing);
      expect(find.text('Manage QR'), findsNothing);
      expect(find.text('Go to Dashboard'), findsOneWidget);
      expect(find.text('Restaurant Branch ID'), findsOneWidget);
      expect(find.text('complete-branch'), findsWidgets);
      expect(find.text('4 Top'), findsOneWidget);
      expect(find.text('Creation Timestamp'), findsOneWidget);
      expect(
        find.text('https://example.test/customer/complete-branch'),
        findsOneWidget,
      );
      expect(find.text('Restaurant & Branch Details'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'Firestore load failure resets loading and renders recovery actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _ScreenRepository(
        error: const AdminContextLoadException('forced read failure'),
      );

      await _pumpOnboarding(tester, repository);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Unable to Load Onboarding'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Go to Dashboard'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}

Future<void> _pumpOnboarding(
  WidgetTester tester,
  RestaurantOnboardingRepository repository,
) {
  final router = GoRouter(
    initialLocation: '/admin/complete-branch/register/onboarding',
    routes: [
      GoRoute(
        path: '/admin/:restaurantBranchId/register/onboarding',
        builder: (_, _) => const RestaurantOnboardingScreen(),
      ),
      GoRoute(
        path: '/admin/:restaurantBranchId/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Dashboard')),
      ),
      GoRoute(
        path: '/admin/login',
        builder: (_, _) => const Scaffold(body: Text('Login')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        restaurantOnboardingRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

class _ScreenRepository implements RestaurantOnboardingRepository {
  const _ScreenRepository({this.context, this.error});

  final RestaurantBranchAdminContext? context;
  final Object? error;

  @override
  Future<RestaurantBranchAdminContext?> loadAdminContext() async {
    if (error case final error?) throw error;
    return context;
  }

  @override
  Future<CompletedRestaurantOnboarding?> completedOnboardingForCurrentAdmin() {
    return Future.value(null);
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
