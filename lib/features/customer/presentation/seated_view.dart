import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/branch_identity_repository.dart';
import '../data/customer_queue_repository.dart';
import 'customer_shell.dart';
import 'seated_greeting.dart';

typedef _SeatedBranchArgs = ({String restaurantSlug, String branchSlug});

final _seatedBranchProvider =
    FutureProvider.family<CustomerBranchLink, _SeatedBranchArgs>((ref, args) {
      return ref
          .watch(branchIdentityRepositoryProvider)
          .resolveCustomerBranch(
            restaurantSlug: args.restaurantSlug,
            branchSlug: args.branchSlug,
          );
    });

class SeatedView extends ConsumerWidget {
  const SeatedView({
    super.key,
    required this.restaurantId,
    required this.branchId,
    required this.queueEntryId,
  });

  final String restaurantId;
  final String branchId;
  final String queueEntryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (
      restaurantId: restaurantId,
      branchId: branchId,
      queueEntryId: queueEntryId,
    );
    final entry = ref.watch(queueEntryProvider(args));
    final branch = ref.watch(
      _seatedBranchProvider((
        restaurantSlug: restaurantId,
        branchSlug: branchId,
      )),
    );
    return CustomerShell(
      restaurantId: restaurantId,
      branchId: branchId,
      activeTab: CustomerTab.status,
      queueEntryId: queueEntryId,
      showBottomNav: false,
      footer: const CustomerFooter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: entry.when(
          data: (entry) => branch.when(
            data: (branch) => _SeatedCard(
              partyName: entry.customerName,
              tableNumber: entry.assignedTableNumber,
              restaurantName: branch.restaurantName,
            ),
            error: (error, _) => ErrorView(message: error.toString()),
            loading: () => const LoadingView(),
          ),
          error: (error, _) => ErrorView(message: error.toString()),
          loading: () => const LoadingView(),
        ),
      ),
    );
  }
}

class _SeatedCard extends StatelessWidget {
  const _SeatedCard({
    required this.partyName,
    required this.tableNumber,
    required this.restaurantName,
  });

  final String partyName;
  final String? tableNumber;
  final String restaurantName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(33),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2212A9DC),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.successGreen,
            size: 96,
          ),
          const SizedBox(height: 24),
          Text(
            seatedGreeting(partyName),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navyText,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are seated at ${tableNumber ?? 'your table'} at $restaurantName.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF3E484F), fontSize: 18),
          ),
          const SizedBox(height: 24),
          const Text(
            'Feedback experience coming soon.',
            style: TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}
