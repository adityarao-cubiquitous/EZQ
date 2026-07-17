import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';

class CustomerLandingScreen extends StatelessWidget {
  const CustomerLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _EzqLogo(),
                  const SizedBox(height: 22),
                  const Text(
                    AppConstants.productName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.navyText,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 40 / 34,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Smart Queue Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF3E484F),
                      fontSize: 18,
                      height: 26 / 18,
                    ),
                  ),
                  const SizedBox(height: 34),
                  EzqButton(
                    label: 'Scan QR code',
                    icon: Icons.qr_code_scanner_rounded,
                    large: true,
                    onPressed: () => context.go('/app/scan'),
                  ),
                  const SizedBox(height: 14),
                  _PhoneSignInButton(onPressed: () => context.go('/app/login')),
                  const SizedBox(height: 28),
                  const _PoweredBy(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EzqLogo extends StatelessWidget {
  const _EzqLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F6FC), Color(0xFFF6FAFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A12A9DC),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const BrandMark(size: 84),
    );
  }
}

class _PhoneSignInButton extends StatelessWidget {
  const _PhoneSignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.phone_iphone_rounded, size: 20),
        label: const Text('Sign in with your phone'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepTeal,
          backgroundColor: Colors.white.withValues(alpha: 0.84),
          side: const BorderSide(color: Color(0x6612A9DC), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _PoweredBy extends StatelessWidget {
  const _PoweredBy();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Container(
          width: 28,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0x66D8EAFE)),
          ),
          child: Image.asset(
            'assets/brand/cubiquitous.png',
            fit: BoxFit.contain,
          ),
        ),
        const Text(
          'Powered by',
          style: TextStyle(color: Color(0xFF3E484F), fontSize: 15),
        ),
        const Text(
          AppConstants.parentBrand,
          style: TextStyle(
            color: AppColors.deepTeal,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
