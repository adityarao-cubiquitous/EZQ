import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../../core/widgets/ezq_text_field.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  bool _obscurePassword = true;

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
                _AdminPasswordField(
                  obscureText: _obscurePassword,
                  onToggleVisibility: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
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
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => context.go('/admin/register'),
                    child: const Text('New manager? Register and Onboard'),
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

class _AdminPasswordField extends StatelessWidget {
  const _AdminPasswordField({
    required this.obscureText,
    required this.onToggleVisibility,
  });

  final bool obscureText;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'Password',
            style: TextStyle(
              color: Color(0xFF3E484F),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.28,
            ),
          ),
        ),
        TextFormField(
          obscureText: obscureText,
          style: const TextStyle(color: AppColors.navyText, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Password',
            hintStyle: const TextStyle(color: Color(0xFF6B7280)),
            suffixIcon: IconButton(
              tooltip: obscureText ? 'Show password' : 'Hide password',
              onPressed: onToggleVisibility,
              icon: Icon(
                obscureText
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.mutedText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
