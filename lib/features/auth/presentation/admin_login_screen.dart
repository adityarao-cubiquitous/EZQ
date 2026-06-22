import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../../core/widgets/ezq_text_field.dart';

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x1412A9DC), blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    BrandMark(size: 28),
                    SizedBox(width: 12),
                    Text(
                      'EZQ',
                      style: TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hostess dashboard',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 16),
                ),
                const SizedBox(height: 32),
                const EzqTextField(
                  label: 'Email',
                  hintText: 'host@example.com',
                ),
                const SizedBox(height: 16),
                const EzqTextField(label: 'Password', hintText: 'Password'),
                const SizedBox(height: 24),
                EzqButton(
                  label: 'Login',
                  onPressed: () => context.go(
                    '/admin/${AppConstants.demoRestaurantId}/branches',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset email flow coming next'),
                      ),
                    ),
                    child: const Text('Forgot password'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
