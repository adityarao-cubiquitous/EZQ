import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class RestaurantDetailsStep extends StatelessWidget {
  const RestaurantDetailsStep({
    super.key,
    required this.adminName,
    required this.adminEmail,
    required this.adminPhone,
    required this.restaurantName,
    required this.branchName,
    required this.area,
    required this.address,
    required this.canContinue,
    required this.onSaveDraft,
    required this.onContinue,
  });

  final String adminName;
  final String adminEmail;
  final String adminPhone;
  final String restaurantName;
  final String branchName;
  final String area;
  final String address;
  final bool canContinue;
  final VoidCallback onSaveDraft;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 768;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepHeader(
                  title: 'Restaurant & Branch Details',
                  subtitle:
                      'Review the restaurant branch assigned to this admin '
                      'before configuring floors and tables.',
                ),
                const SizedBox(height: 32),
                const _InfoBanner(),
                const _SectionDivider(),
                _SectionCard(
                  child: _ReadOnlyDetailsGrid(
                    adminName: adminName,
                    adminEmail: adminEmail,
                    adminPhone: adminPhone,
                    restaurantName: restaurantName,
                    branchName: branchName,
                    area: area,
                    address: address,
                  ),
                ),
                const _SectionDivider(),
                const _LockedIdentityNotice(),
                const _SectionDivider(),
                _FooterActions(
                  isMobile: isMobile,
                  canContinue: canContinue,
                  onSaveDraft: onSaveDraft,
                  onContinue: onContinue,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.navyText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Divider(height: 1, color: AppColors.line),
    );
  }
}

class _ReadOnlyDetailsGrid extends StatelessWidget {
  const _ReadOnlyDetailsGrid({
    required this.adminName,
    required this.adminEmail,
    required this.adminPhone,
    required this.restaurantName,
    required this.branchName,
    required this.area,
    required this.address,
  });

  final String adminName;
  final String adminEmail;
  final String adminPhone;
  final String restaurantName;
  final String branchName;
  final String area;
  final String address;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumns = constraints.maxWidth >= 860;
        final items = [
          _ReadOnlyDetailItem(
            icon: Icons.badge_outlined,
            label: 'Admin Name',
            value: adminName,
          ),
          _ReadOnlyDetailItem(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: adminEmail,
          ),
          _ReadOnlyDetailItem(
            icon: Icons.phone_outlined,
            label: 'Admin Phone',
            value: adminPhone,
          ),
          _ReadOnlyDetailItem(
            icon: Icons.storefront_outlined,
            label: 'Restaurant',
            value: restaurantName,
          ),
          _ReadOnlyDetailItem(
            icon: Icons.apartment_rounded,
            label: 'Branch',
            value: branchName,
          ),
          _ReadOnlyDetailItem(
            icon: Icons.location_on_outlined,
            label: 'Area',
            value: area,
          ),
          _ReadOnlyDetailItem(
            icon: Icons.map_outlined,
            label: 'Address',
            value: address,
          ),
        ];

        if (!useColumns) {
          return Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                items[index],
                if (index != items.length - 1) const SizedBox(height: 16),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            for (final item in items)
              SizedBox(width: (constraints.maxWidth - 24) / 2, child: item),
          ],
        );
      },
    );
  }
}

class _ReadOnlyDetailItem extends StatelessWidget {
  const _ReadOnlyDetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? 'Not specified' : value.trim();

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryTeal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayValue,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.navyText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primaryTeal,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Restaurant branch identity is read-only and comes from the '
              'admin mapping.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.navyText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedIdentityNotice extends StatelessWidget {
  const _LockedIdentityNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        border: Border.all(color: AppColors.warningOrange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.warningOrange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Restaurant, branch, subscription, slug, and QR information are '
              'preserved during onboarding.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.navyText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.isMobile,
    required this.canContinue,
    required this.onSaveDraft,
    required this.onContinue,
  });

  final bool isMobile;
  final bool canContinue;
  final VoidCallback onSaveDraft;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SaveDraftButton(onPressed: onSaveDraft),
          const SizedBox(height: 12),
          _GradientContinueButton(enabled: canContinue, onPressed: onContinue),
        ],
      );
    }

    return Row(
      children: [
        Flexible(child: _SaveDraftButton(onPressed: onSaveDraft)),
        const Spacer(),
        Flexible(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
              child: _GradientContinueButton(
                enabled: canContinue,
                onPressed: onContinue,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveDraftButton extends StatelessWidget {
  const _SaveDraftButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.save_outlined, size: 18),
      label: const Text('Save Draft'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepTeal,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
      ),
    );
  }
}

class _GradientContinueButton extends StatelessWidget {
  const _GradientContinueButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.progressGradient : null,
            color: enabled ? null : AppColors.softSurface,
            borderRadius: BorderRadius.circular(8),
            border: enabled ? null : Border.all(color: AppColors.line),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 15,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continue',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: enabled
                            ? AppColors.background
                            : AppColors.mutedText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: enabled
                          ? AppColors.background
                          : AppColors.mutedText,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
