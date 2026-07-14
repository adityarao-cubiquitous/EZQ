import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/restaurant_branch_access_repository.dart';
import 'customer_shell.dart';

final customerRouteAccessProvider =
    FutureProvider.family<CustomerRouteAccess, String>((
      ref,
      restaurantBranchId,
    ) {
      return ref
          .watch(restaurantBranchAccessRepositoryProvider)
          .checkCustomerAccess(restaurantBranchId);
    }, retry: (_, _) => null);

class CustomerRouteGuard extends ConsumerWidget {
  const CustomerRouteGuard({
    super.key,
    required this.restaurantBranchId,
    required this.child,
  });

  final String restaurantBranchId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(customerRouteAccessProvider(restaurantBranchId));
    return access.when(
      loading: () => const LoadingView(),
      error: (_, _) => const RestaurantSetupInProgressScreen(),
      data: (data) => data.isAllowed
          ? child
          : RestaurantSetupInProgressScreen(reason: data.blockReason),
    );
  }
}

class RestaurantSetupInProgressScreen extends StatelessWidget {
  const RestaurantSetupInProgressScreen({super.key, this.reason});

  final CustomerRouteBlockReason? reason;

  @override
  Widget build(BuildContext context) {
    final title = switch (reason) {
      CustomerRouteBlockReason.restaurantUnavailable ||
      CustomerRouteBlockReason.branchUnavailable => 'Restaurant is unavailable',
      CustomerRouteBlockReason.qrDisabled => 'QR access is not active yet',
      _ => 'Restaurant setup is still in progress',
    };
    final message = switch (reason) {
      CustomerRouteBlockReason.restaurantUnavailable ||
      CustomerRouteBlockReason.branchUnavailable =>
        'This restaurant is not accepting EZQ queues right now.',
      CustomerRouteBlockReason.qrDisabled =>
        'This QR link has not been enabled by the restaurant team yet.',
      _ =>
        'The restaurant team is finishing setup. Please check back in a little while.',
    };

    return CustomerShell(
      restaurantId: '',
      branchId: '',
      activeTab: CustomerTab.join,
      showBottomNav: false,
      appBackRoute: '/app/nearby',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.softSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.construction_rounded,
                color: AppColors.deepTeal,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navyText,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF52666B),
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
