import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/ezq_button.dart';
import 'customer_shell.dart';

class AppInstallPrompt extends StatelessWidget {
  const AppInstallPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final returnTo = _safeCustomerReturnPath(context);

    return CustomerShell(
      restaurantId: AppConstants.demoRestaurantId,
      branchId: AppConstants.demoBranchId,
      showBottomNav: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Use EZQ faster next time',
                style: TextStyle(
                  color: AppColors.navyText,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              const _Benefit(icon: Icons.flash_on, label: 'Faster check-in'),
              const _Benefit(icon: Icons.history, label: 'Visit history'),
              const _Benefit(icon: Icons.notifications, label: 'Push alerts'),
              const _Benefit(
                icon: Icons.local_offer,
                label: 'Offers and loyalty later',
              ),
              const SizedBox(height: 24),
              EzqButton(
                label: 'Sign in with phone',
                icon: Icons.phone_iphone_rounded,
                onPressed: () => context.go('/app/login'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(returnTo ?? '/');
                    }
                  },
                  child: const Text('Continue in browser'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _safeCustomerReturnPath(BuildContext context) {
  final value = GoRouterState.of(context).uri.queryParameters['returnTo'];
  if (value == null || value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (!value.startsWith('/customer/') ||
      value.startsWith('/customer/install')) {
    return null;
  }
  return value;
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.deepTeal),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
