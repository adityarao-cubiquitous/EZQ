import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../../core/widgets/ezq_text_field.dart';
import '../data/auth_repository.dart';
import '../../customer/presentation/customer_shell.dart';

class CustomerPhoneAuthScreen extends ConsumerStatefulWidget {
  const CustomerPhoneAuthScreen({super.key});

  @override
  ConsumerState<CustomerPhoneAuthScreen> createState() =>
      _CustomerPhoneAuthScreenState();
}

class _CustomerPhoneAuthScreenState
    extends ConsumerState<CustomerPhoneAuthScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String? _verificationId;
  String? _normalizedPhone;
  int? _resendToken;
  bool _sendingCode = false;
  bool _verifyingCode = false;

  bool get _codeSent => _verificationId != null && _verificationId!.isNotEmpty;
  bool get _debugOtpEnabled => kDebugMode && !kIsWeb;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!_phoneFormKey.currentState!.validate()) return;
    setState(() => _sendingCode = true);
    try {
      if (_debugOtpEnabled) {
        final normalizedPhone = PhoneUtils.normalizeIndiaMobile(
          _phoneController.text,
        );
        if (!mounted) return;
        setState(() {
          _verificationId = 'debug-otp-bypass';
          _normalizedPhone = normalizedPhone;
          _otpController.text = '123456';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use 123456 as the OTP for now.')),
        );
        return;
      }

      final result = await ref
          .read(customerPhoneAuthRepositoryProvider)
          .startPhoneSignIn(
            phone: _phoneController.text,
            resendToken: resend ? _resendToken : null,
          );
      if (!mounted) return;
      if (result.autoVerified) {
        _goProfile();
        return;
      }
      setState(() {
        _verificationId = result.verificationId;
        _resendToken = result.resendToken ?? _resendToken;
        _normalizedPhone = result.phoneNumber;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resend ? 'Code resent to $_normalizedPhone' : 'Code sent',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _verifyCode() async {
    if (!_otpFormKey.currentState!.validate()) return;
    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) return;
    setState(() => _verifyingCode = true);
    try {
      if (_debugOtpEnabled && verificationId == 'debug-otp-bypass') {
        if (_otpController.text.trim() != '123456') {
          throw StateError('That code does not look right. Please try again.');
        }
        final phone = _normalizedPhone ?? _phoneController.text;
        try {
          await ref
              .read(customerPhoneAuthRepositoryProvider)
              .confirmDebugSmsCode(phone: phone);
        } catch (error) {
          if (!_isAnonymousAuthDisabled(error)) rethrow;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Using local demo login. Enable Anonymous Auth to write customers in Firebase.',
                ),
              ),
            );
          }
        }
        ref.read(debugCustomerPhoneSessionProvider).value = _normalizedPhone;
        if (!mounted) return;
        _goProfile();
        return;
      }

      await ref
          .read(customerPhoneAuthRepositoryProvider)
          .confirmSmsCode(
            verificationId: verificationId,
            smsCode: _otpController.text.trim(),
          );
      if (!mounted) return;
      _goProfile();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  void _goProfile() => context.go('/app/profile');

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('invalid-verification-code')) {
      return 'That code does not look right. Please try again.';
    }
    if (message.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a bit and try again.';
    }
    if (message.contains('requires Firebase')) {
      return 'Run the app with Firebase enabled to use phone sign-in.';
    }
    return message.replaceFirst('Bad state: ', '');
  }

  bool _isAnonymousAuthDisabled(Object error) {
    final message = error.toString();
    return message.contains('admin-restricted-operation') ||
        message.contains('operation is restricted to administrators');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(customerAuthStateProvider);
    authState.whenData((user) {
      if (user != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _goProfile();
        });
      }
    });

    return CustomerShell(
      restaurantId: AppConstants.demoRestaurantId,
      branchId: AppConstants.demoBranchId,
      showBottomNav: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1ABDC8D0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1412A9DC),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _codeSent ? _otpStep() : _phoneStep(),
          ),
        ),
      ),
    );
  }

  Widget _phoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        key: const ValueKey('phone-step'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: _AppBrandBadge()),
          const SizedBox(height: 20),
          const Text(
            'Sign in with phone',
            style: TextStyle(
              color: AppColors.navyText,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use OTP verification for the iOS and Android app experience.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          EzqTextField(
            label: 'Mobile Number',
            hintText: '98765 43210',
            prefixText: '+91  ',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            validator: Validators.indianMobile,
          ),
          const SizedBox(height: 24),
          EzqButton(
            label: _sendingCode ? 'Sending code...' : 'Send OTP',
            icon: Icons.sms_outlined,
            large: true,
            onPressed: _sendingCode ? null : _sendCode,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.go('/app/scan'),
              child: const Text('Continue as guest'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpStep() {
    return Form(
      key: _otpFormKey,
      child: Column(
        key: const ValueKey('otp-step'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter verification code',
            style: TextStyle(
              color: AppColors.navyText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _debugOtpEnabled
                ? 'Use 123456 for ${_normalizedPhone ?? 'this phone number'}.'
                : 'We sent a 6-digit code to ${_normalizedPhone ?? 'your phone'}.',
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          EzqTextField(
            label: 'OTP Code',
            hintText: '123456',
            controller: _otpController,
            keyboardType: TextInputType.number,
            validator: (value) {
              final code = value?.trim() ?? '';
              if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                return 'Enter the 6 digit code';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          EzqButton(
            label: _verifyingCode ? 'Verifying...' : 'Verify and continue',
            icon: Icons.verified_user_outlined,
            large: true,
            onPressed: _verifyingCode ? null : _verifyCode,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _sendingCode
                      ? null
                      : () => _sendCode(resend: true),
                  child: Text(_sendingCode ? 'Resending...' : 'Resend code'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() {
                    _verificationId = null;
                    _otpController.clear();
                  }),
                  child: const Text('Change number'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppBrandBadge extends StatelessWidget {
  const _AppBrandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33BDEAF8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1012A9DC),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Center(child: BrandMark(size: 32)),
    );
  }
}
