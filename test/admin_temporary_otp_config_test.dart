import 'package:ezq/core/utils/phone_utils.dart';
import 'package:ezq/features/auth/data/auth_repository.dart';
import 'package:ezq/features/auth/presentation/admin_login_screen.dart';
import 'package:ezq/features/rest_onboarding/data/restaurant_onboarding_repository.dart';
import 'package:ezq/features/rest_onboarding/domain/onboarding_provisioning.dart';
import 'package:ezq/features/rest_onboarding/providers/restaurant_onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('temporary OTP remains enabled with the shared development code', () {
    expect(TemporaryOtpConfig.enabled, isTrue);
    expect(TemporaryOtpConfig.code, '123456');
  });

  test('affected admin phone uses the shared E.164 normalization', () {
    expect(PhoneUtils.normalizeIndiaMobile('9999001016'), '+919999001016');
    expect(PhoneUtils.normalizeIndiaMobile('+91 99990-01016'), '+919999001016');
  });

  testWidgets(
    'newly provisioned admin is backend-validated and authenticated',
    (tester) async {
      final authRepository = _TrackingAuthRepository();
      final onboardingRepository = _CanonicalOnboardingRepository();
      final router = GoRouter(
        initialLocation: '/admin/login',
        routes: [
          GoRoute(
            path: '/admin/login',
            builder: (context, state) => const AdminLoginScreen(),
          ),
          GoRoute(
            path: '/admin/:restaurantBranchId/dashboard',
            builder: (context, state) =>
                const Scaffold(body: Text('Canonical dashboard')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepository),
            restaurantOnboardingRepositoryProvider.overrideWithValue(
              onboardingRepository,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, '9999001016');
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      expect(authRepository.validatedPhone, '+919999001016');
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();

      expect(authRepository.temporaryPhone, '+919999001016');
      expect(authRepository.temporaryCode, '123456');
      expect(find.text('Canonical dashboard'), findsOneWidget);
    },
  );

  testWidgets('backend-rejected phone never reaches the OTP step', (
    tester,
  ) async {
    final authRepository = _TrackingAuthRepository(rejectValidation: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
        child: const MaterialApp(home: AdminLoginScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '9999009998');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(authRepository.validatedPhone, '+919999009998');
    expect(
      find.text('This phone number is not registered for active admin access.'),
      findsOneWidget,
    );
    expect(find.text('Verify & Continue'), findsNothing);
    expect(authRepository.temporaryPhone, isNull);
  });

  testWidgets('wrong temporary OTP is rejected without authenticating', (
    tester,
  ) async {
    final authRepository = _TrackingAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
        child: const MaterialApp(home: AdminLoginScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '9999001017');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '654321');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('That code does not look right. Please try again.'),
      findsOneWidget,
    );
    expect(authRepository.validatedPhone, '+919999001017');
    expect(authRepository.temporaryPhone, isNull);
  });
}

class _TrackingAuthRepository extends MockAuthRepository {
  _TrackingAuthRepository({this.rejectValidation = false});

  final bool rejectValidation;
  String? validatedPhone;
  String? temporaryPhone;
  String? temporaryCode;

  @override
  Future<void> validateAdminPhoneForOtp({required String phone}) async {
    validatedPhone = phone;
    if (rejectValidation) {
      throw StateError(
        'This phone number is not registered for active admin access.',
      );
    }
  }

  @override
  Future<void> signInAdminWithTemporaryOtp({
    required String phone,
    required String code,
  }) async {
    temporaryPhone = phone;
    temporaryCode = code;
  }
}

class _CanonicalOnboardingRepository implements RestaurantOnboardingRepository {
  @override
  Future<RestaurantBranchAdminContext?> loadAdminContext() async {
    return const RestaurantBranchAdminContext(
      uid: 'GP6NEB4NtDVB0djtILZ0d723Cry2',
      name: 'Saffron Courtyard Bilekahalli Admin',
      email: 'admins.saffron.courtyard.bilekahalli@ezq-demo.cubiquitous.in',
      phone: '+919999001016',
      restaurantBranchId: 'saffron-courtyard-bilekahalli',
      role: 'owner',
      isActive: true,
      onboardingCompleted: true,
      adminOnboardingCompleted: true,
      provisioningStatus: 'completed',
      branchActive: true,
      restaurantName: 'Saffron Courtyard',
      branchName: 'Bilekahalli',
      area: 'Bilekahalli',
      address: 'Bilekahalli Main Road, Bengaluru',
      slug: 'saffron-courtyard-bilekahalli',
    );
  }

  @override
  Future<CompletedRestaurantOnboarding?>
  completedOnboardingForCurrentAdmin() async {
    return const CompletedRestaurantOnboarding(
      restaurantBranchId: 'saffron-courtyard-bilekahalli',
    );
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
