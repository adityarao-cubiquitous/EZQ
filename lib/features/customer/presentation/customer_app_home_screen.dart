import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../auth/data/auth_repository.dart';
import 'customer_shell.dart';

class CustomerAppHomeScreen extends ConsumerWidget {
  const CustomerAppHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(customerAuthStateProvider);
    final debugPhone = ref.watch(debugCustomerPhoneSessionProvider).value;

    return CustomerShell(
      restaurantId: AppConstants.demoRestaurantId,
      branchId: AppConstants.demoBranchId,
      showBottomNav: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: debugPhone != null
            ? _SignedInHome(phoneNumber: debugPhone)
            : authState.when(
                loading: () => const _AppLoadingHome(),
                error: (error, _) => _SignedOutHome(error: error.toString()),
                data: (user) {
                  if (user == null) {
                    return const _SignedOutHome();
                  }
                  return _SignedInHome(phoneNumber: user.phoneNumber);
                },
              ),
      ),
    );
  }
}

class _SignedInHome extends ConsumerWidget {
  const _SignedInHome({this.phoneNumber});

  final String? phoneNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppHeader(
          title: 'EZQ',
          subtitle: phoneNumber == null
              ? 'Ready when you are'
              : 'Signed in as $phoneNumber',
          trailing: IconButton.filledTonal(
            onPressed: () async {
              ref.read(debugCustomerPhoneSessionProvider).value = null;
              await ref.read(customerPhoneAuthRepositoryProvider).signOut();
              if (!context.mounted) return;
              context.go('/app/login');
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ),
        const SizedBox(height: 18),
        _HeroActionPanel(
          title: 'Find a table nearby',
          message:
              'Browse signed-up restaurants around you and join the right queue.',
          buttonLabel: 'Nearby restaurants',
          buttonIcon: Icons.near_me_rounded,
          onPressed: () => context.go('/app/nearby'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _QuickActionTile(
                icon: Icons.confirmation_number_rounded,
                label: 'Join demo queue',
                value: 'Spice House',
                onTap: () => context.go(
                  '/customer/${AppConstants.demoRestaurantId}/${AppConstants.demoBranchId}',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.history_rounded,
                label: 'App benefits',
                value: 'Saved visits',
                onTap: () => context.go('/customer/install'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _StatusPanel(),
      ],
    );
  }
}

class _SignedOutHome extends StatelessWidget {
  const _SignedOutHome({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AppHeader(
          title: 'EZQ',
          subtitle: 'Queues, tables, and restaurant discovery in one app',
        ),
        const SizedBox(height: 18),
        _HeroActionPanel(
          title: 'Start with your phone',
          message:
              error ??
              'Sign in once to use the iOS and Android app experience.',
          buttonLabel: 'Sign in with phone',
          buttonIcon: Icons.phone_iphone_rounded,
          onPressed: () => context.go('/app/login'),
        ),
        const SizedBox(height: 14),
        _SecondaryActionRow(
          leadingLabel: 'Nearby restaurants',
          leadingIcon: Icons.near_me_rounded,
          onLeadingPressed: () => context.go('/app/nearby'),
          trailingLabel: 'Continue as guest',
          trailingIcon: Icons.qr_code_scanner_rounded,
          onTrailingPressed: () => context.go('/app/scan'),
        ),
        const SizedBox(height: 14),
        const _SignedOutValuePanel(),
      ],
    );
  }
}

class _AppLoadingHome extends StatelessWidget {
  const _AppLoadingHome();

  @override
  Widget build(BuildContext context) {
    return const _SurfacePanel(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x33BDEAF8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1012A9DC),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Center(child: BrandMark(size: 26)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navyText,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _HeroActionPanel extends StatelessWidget {
  const _HeroActionPanel({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final IconData buttonIcon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.map_rounded, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navyText,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            EzqButton(
              label: buttonLabel,
              icon: buttonIcon,
              large: true,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 118,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1ABDC8D0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F12A9DC),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.deepTeal),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navyText,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel();

  @override
  Widget build(BuildContext context) {
    return const _SurfacePanel(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: TextStyle(
                color: AppColors.navyText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on_outlined,
              title: 'Nearby discovery',
              subtitle:
                  'Use location to find signed-up restaurants within 2 km.',
            ),
            SizedBox(height: 12),
            _InfoRow(
              icon: Icons.notifications_none_rounded,
              title: 'Queue updates',
              subtitle:
                  'Your active visit will show token and table status here.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedOutValuePanel extends StatelessWidget {
  const _SignedOutValuePanel();

  @override
  Widget build(BuildContext context) {
    return const _SurfacePanel(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.near_me_outlined,
              title: 'Find nearby queues',
              subtitle: 'See signed-up restaurants close to you.',
            ),
            SizedBox(height: 12),
            _InfoRow(
              icon: Icons.table_restaurant_outlined,
              title: 'Track your table',
              subtitle: 'Follow your token from waiting to seated.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActionRow extends StatelessWidget {
  const _SecondaryActionRow({
    required this.leadingLabel,
    required this.leadingIcon,
    required this.onLeadingPressed,
    required this.trailingLabel,
    required this.trailingIcon,
    required this.onTrailingPressed,
  });

  final String leadingLabel;
  final IconData leadingIcon;
  final VoidCallback onLeadingPressed;
  final String trailingLabel;
  final IconData trailingIcon;
  final VoidCallback onTrailingPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OutlineAction(
          label: leadingLabel,
          icon: leadingIcon,
          onPressed: onLeadingPressed,
        ),
        const SizedBox(height: 10),
        _OutlineAction(
          label: trailingLabel,
          icon: trailingIcon,
          onPressed: onTrailingPressed,
        ),
      ],
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepTeal,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          minimumSize: const Size.fromHeight(52),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE9FBFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x4434D5ED)),
          ),
          child: Icon(icon, color: AppColors.deepTeal, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navyText,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }
}
