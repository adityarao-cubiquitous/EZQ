import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../rest_onboarding/providers/restaurant_onboarding_controller.dart';
import '../data/auth_repository.dart';
import '../../rest_onboarding/domain/onboarding_provisioning.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String? _verificationId;
  String? _normalizedPhone;
  int? _resendToken;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  String? _errorText;

  bool get _codeSent => _verificationId != null && _verificationId!.isNotEmpty;
  bool get _isBusy => _sendingCode || _verifyingCode;
  bool get _temporaryOtpBypassEnabled =>
      kDebugMode || const bool.fromEnvironment('ALLOW_ADMIN_OTP_BYPASS');

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_sendingCode) return;
    if (!_phoneFormKey.currentState!.validate()) return;
    setState(() {
      _sendingCode = true;
      _errorText = null;
    });

    try {
      if (_temporaryOtpBypassEnabled) {
        final normalizedPhone = PhoneUtils.normalizeIndiaMobile(
          _phoneController.text,
        );
        setState(() {
          _verificationId = 'temporary-admin-otp-bypass';
          _normalizedPhone = normalizedPhone;
          _resendToken = 1;
          _otpController.text = '123456';
        });
        return;
      }

      final result = await ref
          .read(authRepositoryProvider)
          .startAdminPhoneSignIn(
            phone: _phoneController.text,
            resendToken: resend ? _resendToken : null,
          );
      if (!mounted) return;
      if (result.autoVerified) {
        await _finishAdminLogin();
        return;
      }
      setState(() {
        _verificationId = result.verificationId;
        _normalizedPhone = result.phoneNumber;
        _resendToken = result.resendToken ?? _resendToken;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_verifyingCode) return;
    if (!_otpFormKey.currentState!.validate()) return;
    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) return;

    setState(() {
      _verifyingCode = true;
      _errorText = null;
    });

    try {
      if (_temporaryOtpBypassEnabled &&
          verificationId == 'temporary-admin-otp-bypass') {
        if (_otpController.text.trim() != '123456') {
          throw StateError('That code does not look right. Please try again.');
        }
        _finishTemporaryOtpBypass();
        return;
      }

      await ref
          .read(authRepositoryProvider)
          .confirmAdminSmsCode(
            verificationId: verificationId,
            smsCode: _otpController.text.trim(),
          );
      await _finishAdminLogin();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  void _finishTemporaryOtpBypass() {
    final phone =
        _normalizedPhone ??
        PhoneUtils.normalizeIndiaMobile(_phoneController.text);
    final session = _temporaryAdminSessions[phone];
    if (session == null) {
      setState(
        () => _errorText =
            'No temporary admin mapping was found for $phone. '
            'Create the backend admin mapping before login.',
      );
      return;
    }

    temporaryAdminContext = session.context;
    context.go('/admin/register/onboarding?${session.onboardingQuery}');
  }

  Future<void> _finishAdminLogin() async {
    final adminContext = await ref
        .read(restaurantOnboardingRepositoryProvider)
        .loadAdminContext();
    if (!mounted) return;
    if (adminContext == null) {
      setState(
        () => _errorText =
            'No admin mapping was found for this phone number. '
            'Ask platform support to map this Firebase Auth user to a restaurant.',
      );
      return;
    }
    if (!adminContext.isActive) {
      setState(() => _errorText = 'This admin account is inactive.');
      return;
    }
    if (adminContext.onboardingCompleted) {
      context.go('/admin/${adminContext.restaurantBranchId}/dashboard');
    } else {
      context.go('/admin/register/onboarding');
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('invalid-verification-code')) {
      return 'That code does not look right. Please try again.';
    }
    if (message.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a bit and try again.';
    }
    if (message.contains('network-request-failed')) {
      return 'Firebase Auth could not be reached from this browser session.';
    }
    if (message.contains('requires Firebase')) {
      return 'Run the app with Firebase enabled to use admin phone sign-in.';
    }
    return message.replaceFirst('Bad state: ', '');
  }

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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _codeSent ? _otpStep(context) : _phoneStep(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        SizedBox(height: 8),
        Text(
          'Hostess dashboard',
          style: TextStyle(color: AppColors.mutedText, fontSize: 16),
        ),
      ],
    );
  }

  Widget _phoneStep(BuildContext context) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        key: const ValueKey('admin-phone-step'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 28),
          const Text(
            'Admin access is created by EZQ platform support. Sign in with the mapped phone number.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 14),
          ),
          if (_temporaryOtpBypassEnabled) ...[
            const SizedBox(height: 8),
            const Text(
              'Temporary OTP for local validation: 123456',
              style: TextStyle(color: AppColors.deepTeal, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          _AdminLoginField(
            label: 'Phone Number',
            hintText: '9876543210',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            validator: Validators.indianMobile,
            onSubmitted: (_) => _sendCode(),
          ),
          _errorMessage(context),
          const SizedBox(height: 24),
          EzqButton(
            label: _sendingCode ? 'Sending code...' : 'Send OTP',
            onPressed: _isBusy ? null : _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _otpStep(BuildContext context) {
    return Form(
      key: _otpFormKey,
      child: Column(
        key: const ValueKey('admin-otp-step'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 28),
          Text(
            'Enter the OTP sent to ${_normalizedPhone ?? 'your phone'}.',
            style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _AdminLoginField(
            label: 'OTP',
            hintText: '6 digit code',
            controller: _otpController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            validator: _otpValidator,
            onSubmitted: (_) => _verifyCode(),
          ),
          _errorMessage(context),
          const SizedBox(height: 24),
          EzqButton(
            label: _verifyingCode ? 'Verifying...' : 'Verify & Continue',
            onPressed: _isBusy ? null : _verifyCode,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isBusy
                      ? null
                      : () {
                          setState(() {
                            _verificationId = null;
                            _otpController.clear();
                            _errorText = null;
                          });
                        },
                  child: const Text('Change phone'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _isBusy ? null : () => _sendCode(resend: true),
                  child: const Text('Resend OTP'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorMessage(BuildContext context) {
    if (_errorText == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _errorText!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.errorRed,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String? _otpValidator(String? value) {
    final code = (value ?? '').trim();
    if (code.length < 6) return 'Enter the 6 digit OTP';
    return null;
  }
}

class _TemporaryAdminSession {
  const _TemporaryAdminSession({
    required this.adminUid,
    required this.adminName,
    required this.adminEmail,
    required this.adminPhone,
    required this.restaurantBranchId,
    required this.restaurantName,
    required this.branchName,
    required this.area,
    required this.address,
    required this.slug,
  });

  final String adminUid;
  final String adminName;
  final String adminEmail;
  final String adminPhone;
  final String restaurantBranchId;
  final String restaurantName;
  final String branchName;
  final String area;
  final String address;
  final String slug;

  String get onboardingQuery {
    return Uri(
      queryParameters: {
        'debugAdminUid': adminUid,
        'debugAdminName': adminName,
        'debugAdminEmail': adminEmail,
        'debugAdminPhone': adminPhone,
        'debugRestaurantBranchId': restaurantBranchId,
        'debugRestaurantName': restaurantName,
        'debugBranchName': branchName,
        'debugArea': area,
        'debugAddress': address,
        'debugSlug': slug,
      },
    ).query;
  }

  RestaurantBranchAdminContext get context {
    return RestaurantBranchAdminContext(
      uid: adminUid,
      name: adminName,
      email: adminEmail,
      phone: adminPhone,
      restaurantBranchId: restaurantBranchId,
      role: 'owner',
      isActive: true,
      onboardingCompleted: false,
      restaurantName: restaurantName,
      branchName: branchName,
      area: area,
      address: address,
      slug: slug,
    );
  }
}

const _temporaryAdminSessions = <String, _TemporaryAdminSession>{
  '+919999000222': _TemporaryAdminSession(
    adminUid: 'rfr5L114C2TeR76MsaKRZ1tMDHc2',
    adminName: 'Biryani Bay Admin',
    adminEmail: 'biryani.bay.admin@ezq-demo.cubiquitous.in',
    adminPhone: '+919999000222',
    restaurantBranchId: 'biryani-bay-domlur-edge',
    restaurantName: 'Biryani Bay',
    branchName: 'Domlur Edge',
    area: 'Domlur',
    address: 'Domlur Edge, Bengaluru',
    slug: 'biryani-bay-domlur-edge',
  ),
};

class _AdminLoginField extends StatelessWidget {
  const _AdminLoginField({
    required this.label,
    required this.hintText,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF3E484F),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.28,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          style: const TextStyle(color: AppColors.navyText, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }
}
