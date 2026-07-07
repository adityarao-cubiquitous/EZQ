import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';

class AdminRegistrationScreen extends StatefulWidget {
  const AdminRegistrationScreen({super.key});

  @override
  State<AdminRegistrationScreen> createState() =>
      _AdminRegistrationScreenState();
}

class _AdminRegistrationScreenState extends State<AdminRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _CountryOption _selectedCountry = _countryOptions.first;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitRegistration() {
    if (!_formKey.currentState!.validate()) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '✓',
                style: TextStyle(
                  color: AppColors.successGreen,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Admin Registration Completed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navyText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your admin account has been created successfully.\n'
                'Complete your restaurant onboarding\n'
                'to start using EZQ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FractionallySizedBox(
                widthFactor: 0.86,
                child: _DialogPrimaryButton(
                  label: 'Continue Restaurant Onboarding',
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Restaurant onboarding will be implemented in a future branch.',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateFirstName(String? value) {
    final firstName = (value ?? '').trim();
    if (firstName.length < 2) {
      return 'Enter your first name';
    }
    if (!RegExp(r'^[A-Za-z ]+$').hasMatch(firstName)) {
      return 'Only letters are allowed';
    }
    return null;
  }

  String? _validateLastName(String? value) {
    final lastName = (value ?? '').trim();
    if (lastName.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z ]+$').hasMatch(lastName)) {
      return 'Only letters are allowed';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    final hasMinimumLength = password.length >= 8;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);
    if (!hasMinimumLength || !hasLetter || !hasNumber) {
      return 'Password must contain letters and numbers';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '') != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1412A9DC), blurRadius: 24),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _RegistrationHeader(),
                      const SizedBox(height: 32),
                      const Text(
                        'Create Admin Account',
                        style: TextStyle(
                          color: AppColors.navyText,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _RegistrationTextField(
                        controller: _firstNameController,
                        label: 'First Name *',
                        hintText: 'First name',
                        textInputAction: TextInputAction.next,
                        validator: _validateFirstName,
                      ),
                      const SizedBox(height: 16),
                      _RegistrationTextField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        hintText: 'Last name',
                        textInputAction: TextInputAction.next,
                        validator: _validateLastName,
                      ),
                      const SizedBox(height: 16),
                      _RegistrationTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hintText: 'admin@example.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      _PhoneNumberField(
                        selectedCountry: _selectedCountry,
                        phoneController: _phoneController,
                        onCountryChanged: (country) {
                          if (country == null) return;
                          setState(() => _selectedCountry = country);
                        },
                      ),
                      const SizedBox(height: 16),
                      _RegistrationTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hintText: 'Password',
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        validator: _validatePassword,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _RegistrationTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        hintText: 'Confirm password',
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        validator: _validateConfirmPassword,
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirmPassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      EzqButton(
                        label: 'Confirm',
                        onPressed: _submitRegistration,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/admin/login'),
                          child: const Text('Already registered? Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogPrimaryButton extends StatelessWidget {
  const _DialogPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 50,
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Color(0x2A6A40D7),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegistrationHeader extends StatelessWidget {
  const _RegistrationHeader();

  @override
  Widget build(BuildContext context) {
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
          'Admin Registration',
          style: TextStyle(color: AppColors.mutedText, fontSize: 16),
        ),
      ],
    );
  }
}

class _RegistrationTextField extends StatelessWidget {
  const _RegistrationTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

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
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(color: AppColors.navyText, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF6B7280)),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class _PhoneNumberField extends StatelessWidget {
  const _PhoneNumberField({
    required this.selectedCountry,
    required this.phoneController,
    required this.onCountryChanged,
  });

  final _CountryOption selectedCountry;
  final TextEditingController phoneController;
  final ValueChanged<_CountryOption?> onCountryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'Business Phone Number',
            style: TextStyle(
              color: Color(0xFF3E484F),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.28,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 142,
              child: DropdownButtonFormField<_CountryOption>(
                initialValue: selectedCountry,
                isExpanded: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.mutedText,
                ),
                selectedItemBuilder: (context) {
                  return _countryOptions
                      .map(
                        (country) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${country.flag} ${country.code}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.navyText,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                      .toList();
                },
                items: _countryOptions
                    .map(
                      (country) => DropdownMenuItem<_CountryOption>(
                        value: country,
                        child: Text(
                          '${country.flag} ${country.code} ${country.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onCountryChanged,
              ),
            ),
            Container(
              height: 54,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: AppColors.line,
            ),
            Expanded(
              child: TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  final phone = value ?? '';
                  if (phone.length != 10 || !RegExp(r'^\d+$').hasMatch(phone)) {
                    return 'Enter a valid business phone number';
                  }
                  return null;
                },
                style: const TextStyle(color: AppColors.navyText, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: '9876543210',
                  hintStyle: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountryOption {
  const _CountryOption({
    required this.flag,
    required this.code,
    required this.name,
  });

  final String flag;
  final String code;
  final String name;
}

const _countryOptions = [
  _CountryOption(flag: '🇮🇳', code: '+91', name: 'India'),
  _CountryOption(flag: '🇺🇸', code: '+1', name: 'USA'),
  _CountryOption(flag: '🇬🇧', code: '+44', name: 'UK'),
  _CountryOption(flag: '🇦🇪', code: '+971', name: 'UAE'),
  _CountryOption(flag: '🇸🇬', code: '+65', name: 'Singapore'),
];
