import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../../core/widgets/ezq_text_field.dart';
import '../data/auth_repository.dart';
import '../../customer/presentation/customer_shell.dart';

class CustomerNameProfileScreen extends ConsumerStatefulWidget {
  const CustomerNameProfileScreen({super.key});

  @override
  ConsumerState<CustomerNameProfileScreen> createState() =>
      _CustomerNameProfileScreenState();
}

class _CustomerNameProfileScreenState
    extends ConsumerState<CustomerNameProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _checking = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfileState());
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileState() async {
    final user = ref.read(customerPhoneAuthRepositoryProvider).currentUser();
    final debugPhone = ref.read(debugCustomerPhoneSessionProvider).value;
    if (user == null && debugPhone == null) {
      if (mounted) context.go('/app/login');
      return;
    }

    try {
      final needsName = await ref
          .read(customerProfileRepositoryProvider)
          .needsNameProfile(user);
      if (!mounted) return;
      if (!needsName) {
        context.go('/app/home');
        return;
      }
      setState(() => _checking = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not check profile: $error')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = ref.read(customerPhoneAuthRepositoryProvider).currentUser();
      final debugPhone = ref.read(debugCustomerPhoneSessionProvider).value;
      ref.read(debugCustomerNameProfileProvider).value = CustomerNameProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      await ref
          .read(customerProfileRepositoryProvider)
          .saveNameProfile(
            user: user,
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            phoneNumber: user?.phoneNumber ?? debugPhone,
          );
      if (!mounted) return;
      context.go('/app/home');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save profile: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: _checking ? const _ProfileLoading() : _profileForm(),
        ),
      ),
    );
  }

  Widget _profileForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: _ProfileBrandBadge()),
          const SizedBox(height: 20),
          const Text(
            'Tell us your name',
            style: TextStyle(
              color: AppColors.navyText,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We will use this when you join restaurant queues.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          EzqTextField(
            label: 'First name',
            hintText: 'Anika',
            controller: _firstNameController,
            validator: _nameValidator,
          ),
          const SizedBox(height: 16),
          EzqTextField(
            label: 'Last name',
            hintText: 'Rao',
            controller: _lastNameController,
            validator: _nameValidator,
          ),
          const SizedBox(height: 22),
          EzqButton(
            label: _saving ? 'Saving...' : 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: _saving ? null : _saveProfile,
          ),
        ],
      ),
    );
  }

  String? _nameValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    if (text.length < 2) return 'Enter at least 2 characters';
    return null;
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ProfileBrandBadge extends StatelessWidget {
  const _ProfileBrandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33BDEAF8)),
      ),
      child: const Center(child: BrandMark(size: 28)),
    );
  }
}
