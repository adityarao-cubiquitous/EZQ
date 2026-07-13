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
        await _finishTemporaryOtpBypass();
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

  Future<void> _finishTemporaryOtpBypass() async {
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

    await ref
        .read(authRepositoryProvider)
        .signInAdmin(
          email: session.adminEmail,
          password: session.adminPassword,
        );
    if (!mounted) return;
    if (session.onboardingCompleted) {
      context.go('/admin/${session.restaurantBranchId}/dashboard');
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
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _isBusy ? null : () => context.go('/admin/register'),
              child: const Text('New manager? Register and Onboard'),
            ),
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
    required this.adminPassword,
    required this.adminPhone,
    required this.restaurantBranchId,
    required this.restaurantName,
    required this.branchName,
    required this.area,
    required this.address,
    required this.slug,
    required this.onboardingCompleted,
  });

  final String adminUid;
  final String adminName;
  final String adminEmail;
  final String adminPassword;
  final String adminPhone;
  final String restaurantBranchId;
  final String restaurantName;
  final String branchName;
  final String area;
  final String address;
  final String slug;
  final bool onboardingCompleted;

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
      onboardingCompleted: onboardingCompleted,
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
    adminPassword: 'Welcome@123',
    adminPhone: '+919999000222',
    restaurantBranchId: 'biryani-bay-domlur-edge',
    restaurantName: 'Biryani Bay',
    branchName: 'Domlur Edge',
    area: 'Domlur',
    address: 'Domlur Edge, Bengaluru',
    slug: 'biryani-bay-domlur-edge',
    onboardingCompleted: true,
  ),
  '+919999001001': _TemporaryAdminSession(
    adminUid: 'aN9Xx70ZY5fL3udQDxddQezjYED2',
    adminName: 'Codex Rule Sync Cafe Main Admin',
    adminEmail:
        'admin.codex.rule.sync.cafe.00wh77.main@ezq-demo.cubiquitous.in',
    adminPassword: 'Welcome@123',
    adminPhone: '+919999001001',
    restaurantBranchId: 'codex-rule-sync-cafe-00wh77-main',
    restaurantName: 'Codex Rule Sync Cafe',
    branchName: 'Main',
    area: 'Bilekahalli',
    address: 'Bilekahalli Main Road near IIM Bangalore, Bengaluru',
    slug: 'codex-rule-sync-cafe-00wh77-main',
    onboardingCompleted: true,
  ),
  '+919999001002': _TemporaryAdminSession(
    adminUid: 'A78jcHkH7wMZkHgmVnWDqS6CwPQ2',
    adminName: 'Cubbon Curry Indiranagar Admin',
    adminEmail: 'admin.cubbon.curry.indiranagar@ezq-demo.cubiquitous.in',
    adminPassword: 'Welcome@123',
    adminPhone: '+919999001002',
    restaurantBranchId: 'cubbon-curry-indiranagar',
    restaurantName: 'Cubbon Curry',
    branchName: 'Indiranagar',
    area: 'Arekere',
    address: 'Arekere Gate near Bannerghatta Road, Bengaluru',
    slug: 'cubbon-curry-indiranagar',
    onboardingCompleted: true,
  ),
  '+919999001003': _TemporaryAdminSession(
    adminUid: 'qHyEuqkzG7SRRKcdnh036yZL5R73',
    adminName: 'Dosa Lab Indiranagar Admin',
    adminEmail: 'admin.dosa.lab.indiranagar@ezq-demo.cubiquitous.in',
    adminPassword: 'Welcome@123',
    adminPhone: '+919999001003',
    restaurantBranchId: 'dosa-lab-indiranagar',
    restaurantName: 'Dosa Lab',
    branchName: 'Indiranagar',
    area: 'JP Nagar 7th Phase',
    address: 'JP Nagar 7th Phase near IIM Bangalore, Bengaluru',
    slug: 'dosa-lab-indiranagar',
    onboardingCompleted: true,
  ),
  '+919999001004': _TemporaryAdminSession(
    adminUid: 'e63yLHy0PhYO7KtmdCxzKUiNZkE2',
    adminName: 'Grill Garden Old Airport Road Admin',
    adminEmail: 'admin.grill.garden.old.airport.road@ezq-demo.cubiquitous.in',
    adminPassword: 'Welcome@123',
    adminPhone: '+919999001004',
    restaurantBranchId: 'grill-garden-old-airport-road',
    restaurantName: 'Grill Garden',
    branchName: 'Old Airport Road',
    area: 'Hulimavu',
    address: 'Hulimavu Main Road near IIM Bangalore, Bengaluru',
    slug: 'grill-garden-old-airport-road',
    onboardingCompleted: true,
  ),
  '+919999001005': _TemporaryAdminSession(
    adminUid: 'fg5aGSKR8ad4kdSBAes5van1NJK2',
    adminName: 'Momo Mill Indiranagar Metro Admin',
    adminEmail: 'admin.momo.mill.indiranagar.metro@ezq-demo.cubiquitous.in',
    adminPassword: 'Welcome@123',
    adminPhone: '+919999001005',
    restaurantBranchId: 'momo-mill-indiranagar-metro',
    restaurantName: 'Momo Mill',
    branchName: 'Indiranagar Metro',
    area: 'Bannerghatta Road',
    address: 'Bannerghatta Road, Bengaluru',
    slug: 'momo-mill-indiranagar-metro',
    onboardingCompleted: true,
  ),
  '+919999001006': _TemporaryAdminSession(
    adminUid: 'SyFKT8CDYSgAttPuscL80GuJgtE3',
    adminName: 'Noodle Yard Indiranagar Admin',
    adminEmail: 'admin.noodle.yard.indiranagar@ezq-demo.cubiquitous.in',
    adminPassword: 'Welcome@123',
    adminPhone: '+919999001006',
    restaurantBranchId: 'noodle-yard-indiranagar',
    restaurantName: 'Noodle Yard',
    branchName: 'Indiranagar',
    area: 'Panduranga Nagar',
    address: 'Panduranga Nagar near IIM Bangalore, Bengaluru',
    slug: 'noodle-yard-indiranagar',
    onboardingCompleted: true,
  ),
  '+919999001007': _TemporaryAdminSession(
    adminUid: 'iL2xWHftWwMmBLRWJMLp4n6EbHR2',
    adminName: 'Pasta Pepper HAL 2nd Stage Admin',
    adminEmail: 'admin.pasta.pepper.hal.2nd.stage@ezq-demo.cubiquitous.in',
    adminPassword: 'Welcome@123',
    adminPhone: '+919999001007',
    restaurantBranchId: 'pasta-pepper-hal-2nd-stage',
    restaurantName: 'Pasta Pepper',
    branchName: 'HAL 2nd Stage',
    area: 'BTM 2nd Stage',
    address: 'BTM 2nd Stage near Bannerghatta Road, Bengaluru',
    slug: 'pasta-pepper-hal-2nd-stage',
    onboardingCompleted: true,
  ),
  '+919999001008': _TemporaryAdminSession(
    adminUid: 'qcYCxNc0rRhmI5DC4p8sCWTXhSr1',
    adminName: 'Salad Studio 12th Main Admin',
    adminEmail: 'admin.salad.studio.12th.main@ezq-demo.cubiquitous.in',
    adminPassword: 'Welcome@123',
    adminPhone: '+919999001008',
    restaurantBranchId: 'salad-studio-12th-main',
    restaurantName: 'Salad Studio',
    branchName: '12th Main',
    area: 'Dollars Colony',
    address: 'Dollars Colony JP Nagar near IIM Bangalore, Bengaluru',
    slug: 'salad-studio-12th-main',
    onboardingCompleted: true,
  ),
  '+919999001009': _TemporaryAdminSession(
    adminUid: 'UKE83urkjFU9fLZCz1kOjBsjdel1',
    adminName: 'Taco Tawa Indiranagar Admin',
    adminEmail: 'admin.taco.tawa.indiranagar@ezq-demo.cubiquitous.in',
    adminPassword: 'Welcome@123',
    adminPhone: '+919999001009',
    restaurantBranchId: 'taco-tawa-indiranagar',
    restaurantName: 'Taco Tawa',
    branchName: 'Indiranagar',
    area: 'Arakere Mico Layout',
    address: 'Arakere Mico Layout near Bannerghatta Road, Bengaluru',
    slug: 'taco-tawa-indiranagar',
    onboardingCompleted: true,
  ),
  '+919999001010': _TemporaryAdminSession(
    adminUid: '5QdD9TeOu7avdfHh9gUPkiweiIE3',
    adminName: 'The Spice House Indiranagar Admin',
    adminEmail: 'admin.the.spice.house.indiranagar@ezq-demo.cubiquitous.in',
    adminPassword: 'Welcome@123',
    adminPhone: '+919999001010',
    restaurantBranchId: 'the-spice-house-indiranagar',
    restaurantName: 'The Spice House',
    branchName: 'Indiranagar',
    area: 'Vijaya Bank Layout',
    address: 'Vijaya Bank Layout near IIM Bangalore, Bengaluru',
    slug: 'the-spice-house-indiranagar',
    onboardingCompleted: true,
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
