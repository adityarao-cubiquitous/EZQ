import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_paths.dart';
import 'customer_shell.dart';
import 'restaurant_logo.dart';

class CustomerSupportScreen extends StatelessWidget {
  const CustomerSupportScreen({
    super.key,
    required this.restaurantId,
    required this.branchId,
    this.queueEntryId,
  });

  final String restaurantId;
  final String branchId;
  final String? queueEntryId;

  @override
  Widget build(BuildContext context) {
    final restaurantSlug = FirestorePaths.restaurantBranchIdFromRoute(
      restaurantId,
      branchId,
    );
    return CustomerShell(
      restaurantId: restaurantId,
      branchId: branchId,
      activeTab: CustomerTab.support,
      queueEntryId: queueEntryId,
      appBackRoute: '/app/home',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: RestaurantLogo(restaurantSlug: restaurantSlug)),
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
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.phone, color: AppColors.deepTeal),
                title: Text('Restaurant phone'),
                subtitle: Text('+91 98765 43210'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
