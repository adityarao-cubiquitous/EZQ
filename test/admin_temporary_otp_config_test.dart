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

  test('every configured production demo phone has a temporary mapping', () {
    expect(temporaryAdminConfiguredPhones, <String>{
      '+919999000222',
      for (var suffix = 1; suffix <= 15; suffix++)
        '+919999${(1000 + suffix).toString().padLeft(6, '0')}',
    });
    expect(
      temporaryAdminBranchForPhone('9999001011'),
      'bhagini-horamavu-signal',
    );
    expect(
      temporaryAdminBranchForPhone('+91 99990-01004'),
      'grill-garden-old-airport-road',
    );
  });

  test('temporary session must agree with the canonical admin mapping', () {
    expect(
      temporaryAdminCanonicalMappingMatches(
        requestedPhone: '9999001011',
        canonicalUid: 'ycwQM1bDSqQ2rPunFLNYNpl8Twp2',
        canonicalPhone: '+919999001011',
        canonicalRestaurantBranchId: 'bhagini-horamavu-signal',
      ),
      isTrue,
    );
    expect(
      temporaryAdminCanonicalMappingMatches(
        requestedPhone: '9999001011',
        canonicalUid: 'wrong-uid',
        canonicalPhone: '+919999001011',
        canonicalRestaurantBranchId: 'bhagini-horamavu-signal',
      ),
      isFalse,
    );
    expect(
      temporaryAdminCanonicalMappingMatches(
        requestedPhone: '9999001011',
        canonicalUid: 'ycwQM1bDSqQ2rPunFLNYNpl8Twp2',
        canonicalPhone: '+919999001011',
        canonicalRestaurantBranchId: 'wrong-branch',
      ),
      isFalse,
    );
  });

  test('India phone normalization is stable across supported formats', () {
    expect(PhoneUtils.normalizeIndiaMobile('9999001011'), '+919999001011');
    expect(PhoneUtils.normalizeIndiaMobile('91 99990 01011'), '+919999001011');
    expect(PhoneUtils.normalizeIndiaMobile('+91-99990-01011'), '+919999001011');
  });

  testWidgets(
    'unmapped local phone is backend-validated before temporary OTP login',
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
      await tester.enterText(find.byType(TextFormField).first, '9999009999');
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();
      expect(authRepository.validatedPhone, '+919999009999');
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();

      expect(authRepository.temporaryPhone, '+919999009999');
      expect(authRepository.temporaryCode, '123456');
      expect(find.text('Canonical dashboard'), findsOneWidget);
    },
  );

  testWidgets('backend-unmapped phone never reaches the OTP step', (
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
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.text('Verify & Continue'), findsNothing);
    expect(authRepository.temporaryPhone, isNull);
  });

  testWidgets('wrong temporary OTP is rejected without signing in', (
    tester,
  ) async {
    final authRepository = _TrackingAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
        child: const MaterialApp(home: AdminLoginScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '9999009999');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '654321');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('That code does not look right. Please try again.'),
      findsOneWidget,
    );
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
      uid: 'canonical-admin',
      name: 'Canonical Admin',
      email: 'admin@example.test',
      phone: '+919999009999',
      restaurantBranchId: 'canonical-branch',
      role: 'owner',
      isActive: true,
      onboardingCompleted: true,
      adminOnboardingCompleted: true,
      provisioningStatus: 'completed',
      branchActive: true,
      restaurantName: 'Canonical Restaurant',
      branchName: 'Main',
      area: 'Indiranagar',
      address: '12th Main',
      slug: 'canonical-branch',
    );
  }

  @override
  Future<CompletedRestaurantOnboarding?>
  completedOnboardingForCurrentAdmin() async {
    return const CompletedRestaurantOnboarding(
      restaurantBranchId: 'canonical-branch',
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
