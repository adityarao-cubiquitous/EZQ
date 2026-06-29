import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../features/admin/presentation/admin_dashboard_screen.dart';
import '../features/admin/presentation/branch_selector_screen.dart';
import '../features/auth/presentation/customer_name_profile_screen.dart';
import '../features/auth/presentation/customer_phone_auth_screen.dart';
import '../features/auth/presentation/admin_login_screen.dart';
import '../features/customer/presentation/app_install_prompt.dart';
import '../features/customer/presentation/customer_join_queue_screen.dart';
import '../features/customer/presentation/customer_menu_screen.dart';
import '../features/customer/presentation/customer_queue_status_screen.dart';
import '../features/customer/presentation/customer_qr_scanner_screen.dart';
import '../features/customer/presentation/customer_support_screen.dart';
import '../features/customer/presentation/nearby_restaurants_screen.dart';
import '../features/customer/presentation/seated_view.dart';
import '../features/customer/presentation/table_ready_view.dart';
import '../features/reports/presentation/daily_summary_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  const useAppRoot = !kIsWeb && useFirebase;

  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => useAppRoot
            ? '/app/login'
            : '/customer/${AppConstants.demoRestaurantId}/${AppConstants.demoBranchId}',
      ),
      GoRoute(
        path: '/customer/:restaurantId/:branchId',
        builder: (context, state) => CustomerJoinQueueScreen(
          restaurantId: state.pathParameters['restaurantId']!,
          branchId: state.pathParameters['branchId']!,
        ),
      ),
      GoRoute(
        path: '/customer/:restaurantId/:branchId/status/:queueEntryId',
        builder: (context, state) => CustomerQueueStatusScreen(
          restaurantId: state.pathParameters['restaurantId']!,
          branchId: state.pathParameters['branchId']!,
          queueEntryId: state.pathParameters['queueEntryId']!,
        ),
      ),
      GoRoute(
        path: '/customer/:restaurantId/:branchId/ready/:queueEntryId',
        builder: (context, state) => TableReadyView(
          restaurantId: state.pathParameters['restaurantId']!,
          branchId: state.pathParameters['branchId']!,
          queueEntryId: state.pathParameters['queueEntryId']!,
        ),
      ),
      GoRoute(
        path: '/customer/:restaurantId/:branchId/seated/:queueEntryId',
        builder: (context, state) => SeatedView(
          restaurantId: state.pathParameters['restaurantId']!,
          branchId: state.pathParameters['branchId']!,
          queueEntryId: state.pathParameters['queueEntryId']!,
        ),
      ),
      GoRoute(
        path: '/customer/install',
        builder: (context, state) => const AppInstallPrompt(),
      ),
      GoRoute(
        path: '/customer/:restaurantId/:branchId/menu',
        builder: (context, state) {
          return CustomerMenuScreen(
            restaurantId: state.pathParameters['restaurantId']!,
            branchId: state.pathParameters['branchId']!,
            queueEntryId: state.uri.queryParameters['queueEntryId'],
          );
        },
      ),
      GoRoute(
        path: '/customer/:restaurantId/:branchId/support',
        builder: (context, state) {
          return CustomerSupportScreen(
            restaurantId: state.pathParameters['restaurantId']!,
            branchId: state.pathParameters['branchId']!,
            queueEntryId: state.uri.queryParameters['queueEntryId'],
          );
        },
      ),
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/admin/:restaurantId/branches',
        builder: (context, state) => BranchSelectorScreen(
          restaurantId: state.pathParameters['restaurantId']!,
        ),
      ),
      GoRoute(
        path: '/admin/:restaurantId/:branchId/dashboard',
        builder: (context, state) => AdminDashboardScreen(
          restaurantId: state.pathParameters['restaurantId']!,
          branchId: state.pathParameters['branchId']!,
        ),
      ),
      GoRoute(
        path: '/admin/:restaurantId/:branchId/reports',
        builder: (context, state) => DailySummaryScreen(
          restaurantId: state.pathParameters['restaurantId']!,
          branchId: state.pathParameters['branchId']!,
        ),
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
        builder: (context, state) =>
            const NearbyRestaurantsScreen(appBackRoute: null),
      ),
      GoRoute(
        path: '/app/nearby',
        builder: (context, state) => const NearbyRestaurantsScreen(),
      ),
      GoRoute(
        path: '/app/scan',
        builder: (context, state) => const CustomerQrScannerScreen(),
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
