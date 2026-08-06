import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../queue/domain/queue_entry.dart';
import '../data/branch_identity_repository.dart';
import '../data/customer_queue_repository.dart';
import 'customer_join_location_gate.dart';
import 'customer_join_queue_screen.dart';
import 'customer_shell.dart';

class CustomerDeepLinkScreen extends ConsumerWidget {
  const CustomerDeepLinkScreen({
    super.key,
    required this.restaurantBranchId,
    this.previousQueueEntryId,
    this.appBackRoute,
  });

  final String restaurantBranchId;
  final String? previousQueueEntryId;
  final String? appBackRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(customerBranchLinkProvider(restaurantBranchId));

    return link.when(
      loading: () => const LoadingView(),
      error: (error, _) => _screenFor(error),
      data: (data) {
        final previousId = previousQueueEntryId?.trim();
        if (previousId == null || previousId.isEmpty) {
          return _joinScreen(data);
        }
        final previousEntry = ref.watch(
          queueEntryProvider((
            restaurantBranchId: restaurantBranchId,
            queueEntryId: previousId,
          )),
        );
        return previousEntry.when(
          data: (entry) => entry.status.isTerminal
              ? _joinScreen(data, initialEntry: entry)
              : const _InvalidRejoinScreen(),
          error: (_, _) => const _InvalidRejoinScreen(),
          loading: () => const LoadingView(),
        );
      },
    );
  }

  Widget _joinScreen(CustomerBranchLink data, {QueueEntry? initialEntry}) {
    return CustomerJoinLocationGate(
      branchLink: data,
      child: CustomerJoinQueueScreen(
        restaurantBranchId: restaurantBranchId,
        identity: data.identity,
        initialEntry: initialEntry,
        appBackRoute: appBackRoute,
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

class _InvalidRejoinScreen extends StatelessWidget {
  const _InvalidRejoinScreen();

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      restaurantBranchId: '',
      showBottomNav: false,
      appBackRoute: '/app/home',
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ErrorView(
          message:
              'This previous visit could not be verified. Open your active '
              'visit or choose a restaurant again.',
        ),
      ),
    );
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
      restaurantBranchId: '',
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
