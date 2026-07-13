import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../queue/domain/queue_entry.dart';
import '../../queue/domain/queue_status.dart';
import '../data/customer_queue_repository.dart';
import 'nearby_restaurants_screen.dart';
import 'customer_shell.dart';

class CustomerAppHomeScreen extends ConsumerWidget {
  const CustomerAppHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(customerAuthStateProvider);
    final persistedDebugPhone = ref.watch(persistedDebugCustomerPhoneProvider);
    final debugPhone =
        ref.watch(debugCustomerPhoneSessionProvider).value ??
        persistedDebugPhone.asData?.value;
    final signedInUser = authState.asData?.value;
    final appPhoneNumber = debugPhone ?? signedInUser?.phoneNumber;
    final currentVisit = appPhoneNumber == null
        ? null
        : ref
              .watch(
                currentCustomerVisitProvider((
                  phone: appPhoneNumber,
                  customerId: signedInUser?.uid,
                )),
              )
              .asData
              ?.value;

    return CustomerShell(
      restaurantId: currentVisit?.restaurantId ?? AppConstants.demoRestaurantId,
      branchId: currentVisit?.branchId ?? AppConstants.demoBranchId,
      activeTab: CustomerTab.status,
      queueEntryId: currentVisit?.queueEntryId,
      showBottomNav: currentVisit != null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: debugPhone != null
            ? _SignedInHome(
                phoneNumber: debugPhone,
                customerId: authState.asData?.value?.uid,
              )
            : authState.when(
                loading: () => const _AppLoadingHome(),
                error: (error, _) => _SignedOutHome(error: error.toString()),
                data: (user) {
                  if (user == null) {
                    return const _SignedOutHome();
                  }
                  return _SignedInHome(
                    phoneNumber: user.phoneNumber,
                    customerId: user.uid,
                  );
                },
              ),
      ),
    );
  }
}

class _SignedInHome extends ConsumerWidget {
  const _SignedInHome({this.phoneNumber, this.customerId});

  final String? phoneNumber;
  final String? customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(
      _homeCustomerNameProfileProvider((
        phoneNumber: phoneNumber,
        customerId: customerId,
      )),
    );
    final displayName = profileState.asData?.value?.displayName.trim() ?? '';
    final title = displayName.isNotEmpty ? displayName : 'Welcome back';
    final subtitle = displayName.isNotEmpty
        ? 'Your queue and nearby restaurants'
        : phoneNumber == null
        ? 'Ready when you are'
        : 'Signed in as $phoneNumber';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AccountHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 18),
        _CurrentVisitPanel(phoneNumber: phoneNumber, customerId: customerId),
        const SizedBox(height: 14),
        _HeroActionPanel(
          title: 'Find a table nearby',
          message:
              'Browse signed-up restaurants around you and join the right queue.',
          buttonLabel: 'Nearby restaurants',
          buttonIcon: Icons.near_me_rounded,
          onPressed: () => _openNearbyRestaurants(context, ref),
        ),
      ],
    );
  }
}

class _SignedOutHome extends ConsumerWidget {
  const _SignedOutHome({this.error});

  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          onLeadingPressed: () => _openNearbyRestaurants(context, ref),
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

void _openNearbyRestaurants(BuildContext context, WidgetRef ref) {
  ref.read(nearbyUseDemoLocationProvider.notifier).useCurrentLocation();
  ref.invalidate(nearbyRestaurantsControllerProvider);
  context.go('/app/nearby');
}

final _homeCustomerNameProfileProvider =
    FutureProvider.family<
      CustomerNameProfile?,
      ({String? phoneNumber, String? customerId})
    >((ref, args) {
      final user = ref.watch(customerAuthStateProvider).asData?.value;
      return ref
          .watch(customerProfileRepositoryProvider)
          .loadNameProfile(user, phoneNumber: args.phoneNumber);
    });

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

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navyText,
                  fontSize: 26,
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

class _CurrentVisitPanel extends ConsumerStatefulWidget {
  const _CurrentVisitPanel({required this.phoneNumber, this.customerId});

  final String? phoneNumber;
  final String? customerId;

  @override
  ConsumerState<_CurrentVisitPanel> createState() => _CurrentVisitPanelState();
}

class _CurrentVisitPanelState extends ConsumerState<_CurrentVisitPanel> {
  bool _cancelling = false;

  CurrentVisitLookupArgs? get _lookupArgs {
    final phone = widget.phoneNumber?.trim();
    if (phone == null || phone.isEmpty) return null;
    return (phone: phone, customerId: widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    final args = _lookupArgs;
    if (args == null) return const _NoCurrentVisitPanel();
    final visitState = ref.watch(currentCustomerVisitProvider(args));

    return visitState.when(
      loading: () => const _CurrentVisitLoadingPanel(),
      error: (error, _) => _CurrentVisitErrorPanel(
        onRetry: () => ref.invalidate(currentCustomerVisitProvider(args)),
      ),
      data: (visit) {
        if (visit == null) return const _NoCurrentVisitPanel();
        final entryState = ref.watch(
          queueEntryProvider((
            restaurantId: visit.restaurantId,
            branchId: visit.branchId,
            queueEntryId: visit.queueEntryId,
          )),
        );
        return entryState.when(
          loading: () => const _CurrentVisitLoadingPanel(),
          error: (error, _) => _CurrentVisitErrorPanel(
            onRetry: () => ref.invalidate(
              queueEntryProvider((
                restaurantId: visit.restaurantId,
                branchId: visit.branchId,
                queueEntryId: visit.queueEntryId,
              )),
            ),
          ),
          data: (entry) {
            if (!isCurrentCustomerVisitStatus(entry.status)) {
              return const _NoCurrentVisitPanel();
            }
            return _ActiveVisitCard(
              visit: visit,
              entry: entry,
              cancelling: _cancelling,
              onView: () => context.go(visit.statusRoute),
              onCancel: entry.status == QueueStatus.seated
                  ? null
                  : () => _cancelVisit(visit, entry),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelVisit(CustomerQueueVisit visit, QueueEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.event_busy_rounded, color: Color(0xFFBA1A1A)),
        title: const Text('Leave this queue?'),
        content: Text(
          'Token ${entry.tokenCode} will be cancelled and your place in the queue will be released.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep my place'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel queue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref
          .read(customerQueueRepositoryProvider)
          .cancelQueueEntry(
            restaurantId: visit.restaurantId,
            branchId: visit.branchId,
            queueEntryId: visit.queueEntryId,
            phone: widget.phoneNumber!,
          );
      final args = _lookupArgs;
      if (args != null) ref.invalidate(currentCustomerVisitProvider(args));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your queue entry has been cancelled.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not cancel the queue. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
}

class _ActiveVisitCard extends StatelessWidget {
  const _ActiveVisitCard({
    required this.visit,
    required this.entry,
    required this.cancelling,
    required this.onView,
    required this.onCancel,
  });

  final CustomerQueueVisit visit;
  final QueueEntry entry;
  final bool cancelling;
  final VoidCallback onView;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final seated = entry.status == QueueStatus.seated;
    return _SurfacePanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: seated
                        ? const Color(0xFFE4F8F1)
                        : const Color(0xFFE8F7FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    seated
                        ? Icons.table_restaurant_rounded
                        : Icons.confirmation_number_rounded,
                    color: AppColors.deepTeal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seated ? 'Your table is ready' : 'You’re in the queue',
                        style: const TextStyle(
                          color: AppColors.navyText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _displayBranchName(visit.branchId),
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.navyText,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entry.tokenCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _VisitMetric(
                    label: seated ? 'Table' : 'Queue position',
                    value: seated
                        ? (entry.assignedTableNumber ?? 'Assigned')
                        : '#${entry.queuePosition}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VisitMetric(
                    label: seated ? 'Status' : 'Estimated wait',
                    value: seated
                        ? 'Seated'
                        : '~${entry.estimatedWaitMinutes} min',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            EzqButton(
              label: seated ? 'View table details' : 'View queue',
              icon: Icons.arrow_forward_rounded,
              onPressed: onView,
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 10),
              EzqButton(
                label: cancelling ? 'Cancelling…' : 'Cancel queue',
                destructive: true,
                onPressed: cancelling ? null : onCancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VisitMetric extends StatelessWidget {
  const _VisitMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F9FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navyText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCurrentVisitPanel extends StatelessWidget {
  const _NoCurrentVisitPanel();

  @override
  Widget build(BuildContext context) => const _SurfacePanel(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: _InfoRow(
        icon: Icons.notifications_none_rounded,
        title: 'No active queue',
        subtitle:
            'Join a nearby restaurant and your live visit will appear here.',
      ),
    ),
  );
}

class _CurrentVisitLoadingPanel extends StatelessWidget {
  const _CurrentVisitLoadingPanel();

  @override
  Widget build(BuildContext context) => const _SurfacePanel(
    child: Padding(
      padding: EdgeInsets.all(22),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 14),
          Text('Checking your active queue…'),
        ],
      ),
    ),
  );
}

class _CurrentVisitErrorPanel extends StatelessWidget {
  const _CurrentVisitErrorPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _SurfacePanel(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InfoRow(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn’t load your queue',
            subtitle: 'Check your connection and try again.',
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

String _displayBranchName(String branchId) {
  final words = branchId
      .split(RegExp(r'[-_]'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .toList();
  return words.isEmpty ? 'Your restaurant' : words.join(' ');
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
