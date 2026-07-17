import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_paths.dart';
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
        redirect: (context, state) => _redirectLegacyAdminOnboarding(),
      ),
      GoRoute(
        path: '/admin/:restaurantBranchId/register/onboarding',
        redirect: (context, state) => _redirectAdminBranchRoute(
          state,
          state.pathParameters['restaurantBranchId']!,
        ),
        builder: (context, state) => const RestaurantOnboardingScreen(),
      ),
      GoRoute(
        path: '/admin/:restaurantBranchId/dashboard',
        redirect: (context, state) => _redirectAdminBranchRoute(
          state,
          state.pathParameters['restaurantBranchId']!,
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

Future<String> _redirectLegacyAdminOnboarding() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '/admin/login';

  final adminSnapshot = await FirebaseFirestore.instance
      .doc(FirestorePaths.rootAdmin(user.uid))
      .get();
  final adminData = adminSnapshot.data();
  final restaurantBranchId = (adminData?['restaurantBranchId'] as String? ?? '')
      .trim();
  if (restaurantBranchId.isEmpty) return '/admin/login';

  return _adminBranchDestination(restaurantBranchId);
}

Future<String?> _redirectAdminBranchRoute(
  GoRouterState state,
  String restaurantBranchId,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '/admin/login';

  final adminSnapshot = await FirebaseFirestore.instance
      .doc(FirestorePaths.rootAdmin(user.uid))
      .get();
  final adminData = adminSnapshot.data();
  final mappedRestaurantBranchId =
      (adminData?['restaurantBranchId'] as String? ?? '').trim();
  final isActive = adminData?['isActive'] as bool? ?? false;
  if (!isActive || mappedRestaurantBranchId.isEmpty) {
    return '/admin/login';
  }
  if (mappedRestaurantBranchId != restaurantBranchId) {
    return _adminBranchDestination(mappedRestaurantBranchId);
  }

  final destination = await _adminBranchDestination(mappedRestaurantBranchId);
  if (state.uri.path == destination) return null;
  return destination;
}

Future<String> _adminBranchDestination(String restaurantBranchId) async {
  final branchSnapshot = await FirebaseFirestore.instance
      .doc(FirestorePaths.restaurantBranch(restaurantBranchId))
      .get();
  final branchData = branchSnapshot.data();
  final onboardingCompleted =
      branchData?['onboardingCompleted'] as bool? ?? false;
  if (onboardingCompleted) {
    return '/admin/$restaurantBranchId/dashboard';
  }
  return '/admin/$restaurantBranchId/register/onboarding';
}
