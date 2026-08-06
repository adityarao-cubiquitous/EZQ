import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/branch_identity_repository.dart';
import 'customer_restaurant_identity.dart';
import 'customer_shell.dart';

class CustomerSupportScreen extends ConsumerWidget {
  const CustomerSupportScreen({
    super.key,
    required this.restaurantBranchId,
    this.queueEntryId,
  });

  final String restaurantBranchId;
  final String? queueEntryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(customerBranchLinkProvider(restaurantBranchId));
    return CustomerShell(
      restaurantBranchId: restaurantBranchId,
      activeTab: CustomerTab.support,
      queueEntryId: queueEntryId,
      appBackRoute: '/app/home',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: branch.when(
          loading: () => const LoadingView(),
          error: (_, _) => _SupportCard(
            branch: CustomerBranchLink.fallback(restaurantBranchId),
          ),
          data: (branch) => _SupportCard(branch: branch),
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.branch});

  final CustomerBranchLink branch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CustomerRestaurantIdentityView(identity: branch.identity),
          ),
          const SizedBox(height: 20),
          const Text(
            'Support',
            style: TextStyle(
              color: AppColors.navyText,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Need help with your queue token?'),
          const SizedBox(height: 12),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.support_agent, color: AppColors.deepTeal),
            title: Text('Ask the hostess at the entrance desk'),
            subtitle: Text('Show your token code if you need assistance.'),
          ),
        ],
      ),
    );
  }
}
