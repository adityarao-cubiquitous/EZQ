import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/branch_identity_repository.dart';
import 'customer_join_queue_screen.dart';
import 'customer_shell.dart';

typedef CustomerBranchLinkArgs = ({String restaurantSlug, String branchSlug});

final customerBranchLinkProvider =
    FutureProvider.family<CustomerBranchLink, CustomerBranchLinkArgs>((
      ref,
      args,
    ) {
      return ref
          .watch(branchIdentityRepositoryProvider)
          .resolveCustomerBranch(
            restaurantSlug: args.restaurantSlug,
            branchSlug: args.branchSlug,
          );
    }, retry: (_, _) => null);

class CustomerDeepLinkScreen extends ConsumerWidget {
  const CustomerDeepLinkScreen({
    super.key,
    required this.restaurantSlug,
    required this.branchSlug,
  });

  final String restaurantSlug;
  final String branchSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(
      customerBranchLinkProvider((
        restaurantSlug: restaurantSlug,
        branchSlug: branchSlug,
      )),
    );

    return link.when(
      loading: () => const LoadingView(),
      error: (error, _) => _screenFor(error),
      data: (data) => CustomerJoinQueueScreen(
        restaurantId: data.restaurantId,
        branchSlug: data.branch.id,
        restaurantName: data.restaurantName,
        branchName: data.branch.name,
      ),
    );
  }

  Widget _screenFor(Object error) {
    if (error is CustomerDeepLinkException) {
      return switch (error.failure) {
        CustomerDeepLinkFailure.restaurantClosed =>
          const RestaurantClosedScreen(),
        CustomerDeepLinkFailure.branchNotFound => const BranchNotFoundScreen(),
        CustomerDeepLinkFailure.branchInactive => const BranchInactiveScreen(),
        CustomerDeepLinkFailure.restaurantNotFound =>
          const RestaurantNotFoundScreen(),
      };
    }
    return const RestaurantNotFoundScreen();
  }
}

class RestaurantNotFoundScreen extends StatelessWidget {
  const RestaurantNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DeepLinkErrorScreen(
      title: 'Restaurant Not Found',
      message: 'This EZQ restaurant link is not available.',
      icon: Icons.storefront_outlined,
    );
  }
}

class BranchNotFoundScreen extends StatelessWidget {
  const BranchNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DeepLinkErrorScreen(
      title: 'Branch Not Found',
      message: 'This branch link does not match an active EZQ branch.',
      icon: Icons.location_off_outlined,
    );
  }
}

class RestaurantClosedScreen extends StatelessWidget {
  const RestaurantClosedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DeepLinkErrorScreen(
      title: 'Restaurant Closed',
      message: 'This restaurant is not accepting EZQ queues right now.',
      icon: Icons.no_meals_outlined,
    );
  }
}

class BranchInactiveScreen extends StatelessWidget {
  const BranchInactiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DeepLinkErrorScreen(
      title: 'Branch Inactive',
      message: 'This branch is not accepting queue joins right now.',
      icon: Icons.pause_circle_outline_rounded,
    );
  }
}

class _DeepLinkErrorScreen extends StatelessWidget {
  const _DeepLinkErrorScreen({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      restaurantId: '',
      branchId: '',
      activeTab: CustomerTab.join,
      showBottomNav: false,
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
              child: Icon(icon, color: AppColors.deepTeal, size: 34),
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
