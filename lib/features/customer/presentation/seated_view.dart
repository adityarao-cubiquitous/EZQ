import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'customer_shell.dart';

class SeatedView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return CustomerShell(
      restaurantId: restaurantId,
      branchId: branchId,
      activeTab: CustomerTab.status,
      queueEntryId: queueEntryId,
      showBottomNav: false,
      footer: const CustomerFooter(),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: _SeatedCard(),
      ),
    );
  }
}

class _SeatedCard extends StatelessWidget {
  const _SeatedCard();

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
      child: const Column(
        children: [
          Icon(Icons.check_circle, color: AppColors.successGreen, size: 96),
          SizedBox(height: 24),
          Text(
            'Enjoy your meal!',
            style: TextStyle(
              color: AppColors.navyText,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You are seated at Table T4 at The Spice House.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF3E484F), fontSize: 18),
          ),
          SizedBox(height: 24),
          Text(
            'Feedback experience coming soon.',
            style: TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}
