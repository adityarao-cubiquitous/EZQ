import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
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
    return CustomerShell(
      restaurantId: restaurantId,
      branchId: branchId,
      activeTab: CustomerTab.support,
      queueEntryId: queueEntryId,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: RestaurantLogo()),
              SizedBox(height: 20),
              Text(
                'Support',
                style: TextStyle(
                  color: AppColors.navyText,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 16),
              Text('Need help with your queue token?'),
              SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.support_agent, color: AppColors.deepTeal),
                title: Text('Ask the hostess at the entrance desk'),
                subtitle: Text('Show your token code if you need assistance.'),
              ),
              ListTile(
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
