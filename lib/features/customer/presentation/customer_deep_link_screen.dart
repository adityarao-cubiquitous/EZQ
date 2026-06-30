import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/restaurant_resolver_service.dart';
import 'customer_join_queue_screen.dart';
import 'customer_shell.dart';

typedef CustomerBranchLinkArgs = ({String restaurantSlug, String branchSlug});

final customerBranchLinkProvider =
    FutureProvider.family<RestaurantResolution, CustomerBranchLinkArgs>((
      ref,
      args,
    ) {
      return ref
          .watch(restaurantResolverServiceProvider)
          .resolve(
            restaurantSlug: args.restaurantSlug,
            branchSlug: args.branchSlug,
          );
    });

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
        restaurantId: data.restaurant.id,
        branchId: branchSlug,
        restaurantName: data.branding.restaurantName,
        branchName: data.branding.branchName,
      ),
    );
  }

  Widget _screenFor(Object error) {
    if (error is RestaurantResolverException) {
      return switch (error.failure) {
        RestaurantResolverFailure.restaurantClosed =>
          const RestaurantClosedScreen(),
        RestaurantResolverFailure.branchNotFound =>
          const BranchNotFoundScreen(),
        RestaurantResolverFailure.branchInactive =>
          const BranchInactiveScreen(),
        RestaurantResolverFailure.restaurantNotFound =>
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
