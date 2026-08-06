import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/branch_identity_repository.dart';
import 'customer_shell.dart';

class SeatedView extends ConsumerWidget {
  const SeatedView({
    super.key,
    required this.restaurantBranchId,
    required this.queueEntryId,
  });

  final String restaurantBranchId;
  final String queueEntryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(customerBranchLinkProvider(restaurantBranchId));
    return CustomerShell(
      restaurantBranchId: restaurantBranchId,
      activeTab: CustomerTab.status,
      queueEntryId: queueEntryId,
      showBottomNav: false,
      footer: const CustomerFooter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: branch.when(
          data: (branch) => _SeatedCard(
            restaurantName: branch.restaurantName,
            branchName: branch.branch.name,
          ),
          error: (error, _) => ErrorView(message: error.toString()),
          loading: () => const LoadingView(),
        ),
      ),
    );
  }
}

class _SeatedCard extends StatelessWidget {
  const _SeatedCard({required this.restaurantName, required this.branchName});

  final String restaurantName;
  final String branchName;

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
          const Text(
            'Enjoy your meal!',
            style: TextStyle(
              color: AppColors.navyText,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are seated at Table T4 at $restaurantName, $branchName.',
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
