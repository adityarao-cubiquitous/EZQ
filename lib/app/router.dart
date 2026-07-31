import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../features/admin/presentation/admin_dashboard_screen.dart';
import '../features/auth/presentation/customer_name_profile_screen.dart';
import '../features/auth/presentation/customer_phone_auth_screen.dart';
import '../features/auth/presentation/admin_login_screen.dart';
import '../features/customer/presentation/app_install_prompt.dart';
import '../features/customer/presentation/customer_deep_link_screen.dart';
import '../features/customer/presentation/customer_app_home_screen.dart';
import '../features/customer/presentation/customer_landing_screen.dart';
import '../features/customer/presentation/customer_menu_screen.dart';
import '../features/customer/presentation/customer_queue_status_screen.dart';
import '../features/customer/presentation/customer_qr_scanner_screen.dart';
import '../features/customer/presentation/customer_route_guard.dart';
import '../features/customer/presentation/customer_support_screen.dart';
import '../features/customer/presentation/nearby_restaurants_screen.dart';
import '../features/customer/presentation/seated_view.dart';
import '../features/customer/presentation/table_ready_view.dart';
import '../features/reports/presentation/daily_summary_screen.dart';
import '../features/rest_onboarding/presentation/screens/restaurant_onboarding_screen.dart';
import '../features/rest_onboarding/data/restaurant_onboarding_repository.dart';
import '../features/rest_onboarding/domain/onboarding_provisioning.dart';
import '../features/rest_onboarding/providers/restaurant_onboarding_controller.dart';
import 'admin_branch_route_policy.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const CustomerLandingScreen(),
      ),
      GoRoute(
        path: '/customer/:restaurantBranchId',
        builder: (context, state) {
          final restaurantBranchId =
              state.pathParameters['restaurantBranchId']!;
          return CustomerRouteGuard(
            restaurantBranchId: restaurantBranchId,
            child: CustomerDeepLinkScreen(
              restaurantSlug: restaurantBranchId,
              branchSlug: restaurantBranchId,
            ),
          );
        },
      ),
      GoRoute(
        path: '/customer/:restaurantBranchId/status/:queueEntryId',
        builder: (context, state) {
          final restaurantBranchId =
              state.pathParameters['restaurantBranchId']!;
          return CustomerRouteGuard(
            restaurantBranchId: restaurantBranchId,
            child: CustomerQueueStatusScreen(
              restaurantId: restaurantBranchId,
              branchId: restaurantBranchId,
              queueEntryId: state.pathParameters['queueEntryId']!,
            ),
          );
        },
      ),
      GoRoute(
        path: '/customer/:restaurantBranchId/ready/:queueEntryId',
        builder: (context, state) {
          final restaurantBranchId =
              state.pathParameters['restaurantBranchId']!;
          return CustomerRouteGuard(
            restaurantBranchId: restaurantBranchId,
            child: TableReadyView(
              restaurantId: restaurantBranchId,
              branchId: restaurantBranchId,
              queueEntryId: state.pathParameters['queueEntryId']!,
            ),
          );
        },
      ),
      GoRoute(
        path: '/customer/:restaurantBranchId/seated/:queueEntryId',
        builder: (context, state) {
          final restaurantBranchId =
              state.pathParameters['restaurantBranchId']!;
          return CustomerRouteGuard(
            restaurantBranchId: restaurantBranchId,
            child: SeatedView(
              restaurantId: restaurantBranchId,
              branchId: restaurantBranchId,
              queueEntryId: state.pathParameters['queueEntryId']!,
            ),
          );
        },
      ),
      GoRoute(
        path: '/customer/:restaurantBranchId/menu',
        builder: (context, state) {
          final restaurantBranchId =
              state.pathParameters['restaurantBranchId']!;
          return CustomerRouteGuard(
            restaurantBranchId: restaurantBranchId,
            child: CustomerMenuScreen(
              restaurantId: restaurantBranchId,
              branchId: restaurantBranchId,
              queueEntryId: state.uri.queryParameters['queueEntryId'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/customer/:restaurantBranchId/support',
        builder: (context, state) {
          final restaurantBranchId =
              state.pathParameters['restaurantBranchId']!;
          return CustomerRouteGuard(
            restaurantBranchId: restaurantBranchId,
            child: CustomerSupportScreen(
              restaurantId: restaurantBranchId,
              branchId: restaurantBranchId,
              queueEntryId: state.uri.queryParameters['queueEntryId'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/customer/install',
        builder: (context, state) => const AppInstallPrompt(),
      ),
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/admin/register/onboarding',
        redirect: (context, state) => _redirectLegacyAdminOnboarding(
          ref.read(restaurantOnboardingRepositoryProvider),
        ),
      ),
      GoRoute(
        path: '/admin/:restaurantBranchId/register/onboarding',
        redirect: (context, state) => _redirectAdminBranchRoute(
          state,
          state.pathParameters['restaurantBranchId']!,
          ref.read(restaurantOnboardingRepositoryProvider),
          allowCompletedOnboardingSummary: true,
        ),
        builder: (context, state) => const RestaurantOnboardingScreen(),
      ),
      GoRoute(
        path: '/admin/:restaurantBranchId/dashboard',
        redirect: (context, state) => _redirectAdminBranchRoute(
          state,
          state.pathParameters['restaurantBranchId']!,
          ref.read(restaurantOnboardingRepositoryProvider),
        ),
        builder: (context, state) {
          final restaurantBranchId =
              state.pathParameters['restaurantBranchId']!;
          return AdminDashboardScreen(
            restaurantId: restaurantBranchId,
            branchId: restaurantBranchId,
          );
        },
      ),
      GoRoute(
        path: '/admin/:restaurantBranchId/reports',
        redirect: (context, state) => _redirectAdminBranchRoute(
          state,
          state.pathParameters['restaurantBranchId']!,
          ref.read(restaurantOnboardingRepositoryProvider),
        ),
        builder: (context, state) {
          final restaurantBranchId =
              state.pathParameters['restaurantBranchId']!;
          return DailySummaryScreen(
            restaurantId: restaurantBranchId,
            branchId: restaurantBranchId,
          );
        },
      ),
      GoRoute(
        path: '/app/login',
        builder: (context, state) => const CustomerPhoneAuthScreen(),
      ),
      GoRoute(
        path: '/app/profile',
        builder: (context, state) => const CustomerNameProfileScreen(),
      ),
      GoRoute(
        path: '/app/account',
        builder: (context, state) =>
            const CustomerNameProfileScreen(editing: true),
      ),
      GoRoute(
        path: '/app/home',
        builder: (context, state) => const CustomerAppHomeScreen(),
      ),
      GoRoute(
        path: '/app/nearby',
        builder: (context, state) => const NearbyRestaurantsScreen(),
      ),
      GoRoute(
        path: '/app/scan',
        builder: (context, state) =>
            const CustomerQrScannerScreen(appBackRoute: '/app/home'),
      ),
      GoRoute(
        path: '/app/queue/:queueEntryId',
        builder: (context, state) => CustomerQueueStatusScreen(
          restaurantId: AppConstants.demoRestaurantId,
          branchId: AppConstants.demoBranchId,
          queueEntryId: state.pathParameters['queueEntryId']!,
        ),
      ),
    ],
  );
});

Future<String> _redirectLegacyAdminOnboarding(
  RestaurantOnboardingRepository onboardingRepository,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '/admin/login';

  try {
    final adminContext = await onboardingRepository.loadAdminContext();
    if (adminContext == null || !adminContext.isActive) return '/admin/login';
    return _adminBranchDestination(adminContext);
  } on AdminContextLoadException {
    return '/admin/login';
  }
}

Future<String?> _redirectAdminBranchRoute(
  GoRouterState state,
  String restaurantBranchId,
  RestaurantOnboardingRepository onboardingRepository, {
  bool allowCompletedOnboardingSummary = false,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '/admin/login';

  RestaurantBranchAdminContext? adminContext;
  try {
    adminContext = await onboardingRepository.loadAdminContext();
  } on AdminContextLoadException {
    final onboardingPath = '/admin/$restaurantBranchId/register/onboarding';
    return state.uri.path == onboardingPath ? null : onboardingPath;
  }
  if (adminContext == null || !adminContext.isActive) {
    return '/admin/login';
  }
  final mappedRestaurantBranchId = adminContext.restaurantBranchId;
  if (mappedRestaurantBranchId != restaurantBranchId) {
    return _adminBranchDestination(adminContext);
  }
  if (!adminContext.isProvisioningCompleted) {
    final onboardingPath = '/admin/$restaurantBranchId/register/onboarding';
    return state.uri.path == onboardingPath ? null : onboardingPath;
  }

  return resolveAdminBranchRouteRedirect(
    currentPath: state.uri.path,
    restaurantBranchId: mappedRestaurantBranchId,
    branchReady: adminContext.isProvisioningCompleted,
    allowCompletedOnboardingSummary: allowCompletedOnboardingSummary,
  );
}

String _adminBranchDestination(RestaurantBranchAdminContext adminContext) {
  final restaurantBranchId = adminContext.restaurantBranchId;
  if (adminContext.isProvisioningCompleted) {
    return '/admin/$restaurantBranchId/dashboard';
  }
  return '/admin/$restaurantBranchId/register/onboarding';
}
