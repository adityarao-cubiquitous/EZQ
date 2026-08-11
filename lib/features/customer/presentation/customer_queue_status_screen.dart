import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../../core/widgets/loading_view.dart';
import '../../queue/domain/queue_entry.dart';
import '../../queue/domain/queue_status.dart';
import '../data/branch_identity_repository.dart';
import '../data/customer_queue_repository.dart';
import '../domain/party_ahead_copy.dart';
import '../domain/queue_eta.dart';
import '../domain/restaurant_branch_identity.dart';
import 'customer_restaurant_identity.dart';
import 'customer_shell.dart';

enum CustomerQueueRouteExpectation { any, tableReady, seated }

class CustomerQueueStatusScreen extends ConsumerWidget {
  const CustomerQueueStatusScreen({
    super.key,
    required this.restaurantBranchId,
    required this.queueEntryId,
    this.routeExpectation = CustomerQueueRouteExpectation.any,
  });

  final String restaurantBranchId;
  final String queueEntryId;
  final CustomerQueueRouteExpectation routeExpectation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CustomerQueueStatusBody(
      restaurantBranchId: restaurantBranchId,
      queueEntryId: queueEntryId,
      routeExpectation: routeExpectation,
    );
  }
}

class _CustomerQueueStatusBody extends ConsumerWidget {
  const _CustomerQueueStatusBody({
    required this.restaurantBranchId,
    required this.queueEntryId,
    required this.routeExpectation,
  });

  final String restaurantBranchId;
  final String queueEntryId;
  final CustomerQueueRouteExpectation routeExpectation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(
      customerQueueStateProvider((
        restaurantBranchId: restaurantBranchId,
        queueEntryId: queueEntryId,
      )),
    );
    final branchLink = ref.watch(
      customerBranchLinkProvider(restaurantBranchId),
    );

    Widget queueContent(CustomerBranchLink resolvedBranch) {
      return queueState.when(
        data: (state) {
          final entry = state.entry;
          if (!_matchesRouteExpectation(entry, routeExpectation)) {
            return const _InvalidQueueLinkContent();
          }
          if (_requiresAssignedTableValidation(entry.status)) {
            final validation = ref.watch(
              assignedTableValidationProvider((
                restaurantBranchId: restaurantBranchId,
                entry: entry,
              )),
            );
            return validation.when(
              data: (isValid) => isValid
                  ? _statusContentForEntry(
                      ref,
                      entry,
                      resolvedBranch,
                      state.partiesAhead,
                    )
                  : const _InvalidQueueLinkContent(),
              error: (_, _) => const _InvalidQueueLinkContent(),
              loading: () => const SizedBox(height: 700, child: LoadingView()),
            );
          }
          return _statusContentForEntry(
            ref,
            entry,
            resolvedBranch,
            state.partiesAhead,
          );
        },
        error: (error, _) => _InvalidQueueLinkContent(
          debugMessage: kDebugMode ? error.toString() : null,
        ),
        loading: () => const SizedBox(height: 700, child: LoadingView()),
      );
    }

    return CustomerShell(
      restaurantBranchId: restaurantBranchId,
      activeTab: CustomerTab.status,
      queueEntryId: queueEntryId,
      appBackRoute: '/app/home',
      child: branchLink.when(
        data: queueContent,
        error: (_, _) =>
            queueContent(CustomerBranchLink.fallback(restaurantBranchId)),
        loading: () => const SizedBox(height: 700, child: LoadingView()),
      ),
    );
  }

  Widget _statusContentForEntry(
    WidgetRef ref,
    QueueEntry entry,
    CustomerBranchLink resolvedBranch,
    int partiesAhead,
  ) {
    return switch (entry.status) {
      QueueStatus.waiting => _StatusContent(
        restaurantBranchId: restaurantBranchId,
        queueEntryId: queueEntryId,
        branchLink: resolvedBranch,
        entry: entry,
        aheadCount: partiesAhead,
      ),
      QueueStatus.reserved ||
      QueueStatus.onTheWay ||
      QueueStatus.seated ||
      QueueStatus.completed ||
      QueueStatus.cancelled ||
      QueueStatus.skipped ||
      QueueStatus.noShow ||
      QueueStatus.expired => _StatusContent(
        restaurantBranchId: restaurantBranchId,
        queueEntryId: queueEntryId,
        branchLink: resolvedBranch,
        entry: entry,
      ),
    };
  }
}

bool _requiresAssignedTableValidation(QueueStatus status) =>
    status == QueueStatus.reserved ||
    status == QueueStatus.onTheWay ||
    status == QueueStatus.seated;

bool _matchesRouteExpectation(
  QueueEntry entry,
  CustomerQueueRouteExpectation expectation,
) {
  return switch (expectation) {
    CustomerQueueRouteExpectation.any => true,
    CustomerQueueRouteExpectation.tableReady =>
      entry.status == QueueStatus.reserved ||
          entry.status == QueueStatus.onTheWay,
    CustomerQueueRouteExpectation.seated => entry.status == QueueStatus.seated,
  };
}

typedef AssignedTableValidationArgs = ({
  String restaurantBranchId,
  QueueEntry entry,
});

final assignedTableValidationProvider =
    FutureProvider.family<bool, AssignedTableValidationArgs>((ref, args) {
      return ref
          .watch(customerQueueRepositoryProvider)
          .validateAssignedTables(
            restaurantBranchId: args.restaurantBranchId,
            entry: args.entry,
          );
    });

class _InvalidQueueLinkContent extends StatelessWidget {
  const _InvalidQueueLinkContent({this.debugMessage});

  final String? debugMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('invalid-queue-link'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _Card(
        child: Column(
          children: [
            const Icon(
              Icons.link_off_rounded,
              color: AppColors.warningOrange,
              size: 58,
            ),
            const SizedBox(height: 18),
            const Text(
              'Invalid Queue Link',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navyText,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This queue link is unavailable, no longer matches this visit, '
              'or does not have a valid table assignment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            if (debugMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                debugMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 18),
            EzqButton(
              label: 'Return Home',
              icon: Icons.home_rounded,
              onPressed: () => context.go(kIsWeb ? '/' : '/app/home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusContent extends ConsumerWidget {
  const _StatusContent({
    required this.restaurantBranchId,
    required this.queueEntryId,
    required this.branchLink,
    required this.entry,
    this.aheadCount = 0,
  });

  final String restaurantBranchId;
  final String queueEntryId;
  final CustomerBranchLink branchLink;
  final QueueEntry entry;
  final int aheadCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusCard = switch (entry.status) {
      QueueStatus.waiting => _QueueStatusCard(
        entry: entry,
        branchLink: branchLink,
        aheadCount: aheadCount,
      ),
      QueueStatus.reserved => _InlineReadyCard(
        restaurantBranchId: restaurantBranchId,
        branchLink: branchLink,
        entry: entry,
        onTheWay: false,
      ),
      QueueStatus.onTheWay => _InlineReadyCard(
        restaurantBranchId: restaurantBranchId,
        branchLink: branchLink,
        entry: entry,
        onTheWay: true,
      ),
      QueueStatus.seated => _InlineSeatedCard(
        entry: entry,
        branchLink: branchLink,
      ),
      QueueStatus.completed => _TerminalStatusCard(
        identity: branchLink.identity,
        status: QueueStatus.completed,
        title: 'Meal Completed',
        message: 'Your meal is complete. Thank you for dining with us.',
        icon: Icons.check_circle_rounded,
        accentColor: AppColors.successGreen,
        surfaceColor: const Color(0xFFEAF8F1),
      ),
      QueueStatus.cancelled => _TerminalStatusCard(
        identity: branchLink.identity,
        status: QueueStatus.cancelled,
        title: 'Queue Exited',
        message:
            'You chose to exit this queue. Your place is no longer being held.',
        icon: Icons.logout_rounded,
        accentColor: const Color(0xFFBA1A1A),
        surfaceColor: const Color(0xFFFFF1F1),
      ),
      QueueStatus.skipped => _TerminalStatusCard(
        identity: branchLink.identity,
        status: QueueStatus.skipped,
        title: 'Queue Token Skipped',
        message:
            'The restaurant skipped your token before seating. Please speak '
            'with the host if you still wish to dine.',
        icon: Icons.skip_next_rounded,
        accentColor: AppColors.warningOrange,
        surfaceColor: const Color(0xFFFFF6E8),
      ),
      QueueStatus.noShow => _TerminalStatusCard(
        identity: branchLink.identity,
        status: QueueStatus.noShow,
        title: 'Queue Token Closed',
        message:
            'The restaurant closed your token after your party did not arrive '
            'in time.',
        icon: Icons.person_off_rounded,
        accentColor: const Color(0xFF9B3C17),
        surfaceColor: const Color(0xFFFFF0E8),
      ),
      QueueStatus.expired => _TerminalStatusCard(
        identity: branchLink.identity,
        status: QueueStatus.expired,
        title: 'Queue Token Expired',
        message:
            'This queue token is no longer active. Join again if you still '
            'need a table.',
        icon: Icons.timer_off_rounded,
        accentColor: const Color(0xFFBA1A1A),
        surfaceColor: const Color(0xFFFFF1F1),
        detail: 'Token ${entry.tokenCode}',
      ),
    };
    final actions = switch (entry.status) {
      QueueStatus.waiting ||
      QueueStatus.reserved ||
      QueueStatus.onTheWay ||
      QueueStatus.seated => _StatusActions(
        restaurantBranchId: restaurantBranchId,
        queueEntryId: queueEntryId,
        entry: entry,
        showCancel: entry.status.canBeCancelledByCustomer,
      ),
      QueueStatus.completed ||
      QueueStatus.cancelled ||
      QueueStatus.skipped ||
      QueueStatus.noShow ||
      QueueStatus.expired => _TerminalStatusActions(
        restaurantBranchId: restaurantBranchId,
        queueEntryId: queueEntryId,
        status: entry.status,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          statusCard,
          const SizedBox(height: 14),
          actions,
          const SizedBox(height: 116),
        ],
      ),
    );
  }
}

class _StatusActions extends ConsumerStatefulWidget {
  const _StatusActions({
    required this.restaurantBranchId,
    required this.queueEntryId,
    required this.entry,
    required this.showCancel,
  });

  final String restaurantBranchId;
  final String queueEntryId;
  final QueueEntry entry;
  final bool showCancel;

  @override
  ConsumerState<_StatusActions> createState() => _StatusActionsState();
}

class _StatusActionsState extends ConsumerState<_StatusActions> {
  bool _exiting = false;

  Future<void> _exitQueue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.event_busy_rounded, color: Color(0xFFBA1A1A)),
        title: const Text('Exit Queue?'),
        content: const Text(
          'You will lose your place in this queue. You can join again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep My Place'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit Queue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _exiting = true);
    try {
      await ref
          .read(customerQueueRepositoryProvider)
          .cancelQueueEntry(
            restaurantBranchId: widget.restaurantBranchId,
            queueEntryId: widget.queueEntryId,
            phone: widget.entry.phone,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have exited the queue.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not exit the queue.')),
      );
    } finally {
      if (mounted) setState(() => _exiting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EzqButton(
          label: 'View Menu',
          icon: Icons.restaurant_menu_rounded,
          onPressed: () => context.go(
            Uri(
              path:
                  '${FirestorePaths.customerRoute(widget.restaurantBranchId)}/menu',
              queryParameters: {'queueEntryId': widget.queueEntryId},
            ).toString(),
          ),
        ),
        if (widget.showCancel) ...[
          const SizedBox(height: 10),
          SizedBox(
            key: const ValueKey('queue-status-cancel-action'),
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _exiting ? null : _exitQueue,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text(_exiting ? 'Exiting...' : 'Exit Queue'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFBA1A1A),
                side: const BorderSide(color: Color(0x33BA1A1A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        const _InlinePoweredBy(),
        const SizedBox(height: 14),
        const _SponsoredAdCard(),
        const SizedBox(height: 14),
        _HiddenObjectImageCard(restaurantBranchId: widget.restaurantBranchId),
      ],
    );
  }
}

class _TerminalStatusActions extends StatelessWidget {
  const _TerminalStatusActions({
    required this.restaurantBranchId,
    required this.queueEntryId,
    required this.status,
  });

  final String restaurantBranchId;
  final String queueEntryId;
  final QueueStatus status;

  @override
  Widget build(BuildContext context) {
    final showMenu =
        status == QueueStatus.completed || status == QueueStatus.skipped;
    return Column(
      children: [
        EzqButton(
          key: const ValueKey('queue-status-join-again'),
          label: 'Join Queue Again',
          icon: Icons.refresh_rounded,
          onPressed: () => context.go(
            Uri(
              path: FirestorePaths.customerRoute(restaurantBranchId),
              queryParameters: {'rejoinFrom': queueEntryId},
            ).toString(),
          ),
        ),
        if (showMenu) ...[
          const SizedBox(height: 10),
          SizedBox(
            key: const ValueKey('queue-status-view-menu'),
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => context.go(
                Uri(
                  path:
                      '${FirestorePaths.customerRoute(restaurantBranchId)}/menu',
                  queryParameters: {'queueEntryId': queueEntryId},
                ).toString(),
              ),
              icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
              label: const Text('View Menu'),
              style: _terminalActionStyle(),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          key: const ValueKey('queue-status-browse-restaurants'),
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => context.go(kIsWeb ? '/' : '/app/nearby'),
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: const Text('Browse Restaurants'),
            style: _terminalActionStyle(),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          key: const ValueKey('queue-status-return-home'),
          width: double.infinity,
          height: 50,
          child: TextButton.icon(
            onPressed: () => context.go(kIsWeb ? '/' : '/app/home'),
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('Return Home'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.deepTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _InlinePoweredBy(),
      ],
    );
  }

  ButtonStyle _terminalActionStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.deepTeal,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class _TerminalStatusCard extends StatelessWidget {
  const _TerminalStatusCard({
    required this.identity,
    required this.status,
    required this.title,
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.surfaceColor,
    this.detail,
  });

  final RestaurantBranchIdentity identity;
  final QueueStatus status;
  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final Color surfaceColor;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('queue-status-${status.wireName}'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1412A9DC),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              key: ValueKey('queue-status-icon-${status.wireName}'),
              color: accentColor,
              size: 44,
              semanticLabel: '$title status',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navyText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          CustomerRestaurantIdentityView(identity: identity),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF3E484F),
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accentColor.withValues(alpha: 0.18)),
              ),
              child: Text(
                detail!,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlinePoweredBy extends StatelessWidget {
  const _InlinePoweredBy();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Powered by Cubiquitous',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x1AD8EAFE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Image.asset(
                'assets/brand/cubiquitous.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Powered by',
              style: TextStyle(
                color: Color(0xFF607D8B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Cubiquitous',
              style: TextStyle(
                color: AppColors.deepTeal,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsoredAdCard extends StatefulWidget {
  const _SponsoredAdCard();

  @override
  State<_SponsoredAdCard> createState() => _SponsoredAdCardState();
}

class _SponsoredAdCardState extends State<_SponsoredAdCard> {
  late final _DemoAd _ad = _demoAds[math.Random().nextInt(_demoAds.length)];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sponsored ad. ${_ad.title}. ${_ad.body}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x1AD8EAFE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F006687),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _ad.tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_ad.icon, color: _ad.tint, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Sponsored',
                          style: TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _ad.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navyText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _ad.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF607D8B),
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoAd {
  const _DemoAd({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String body;
}

const _demoAds = [
  _DemoAd(
    icon: Icons.local_cafe_rounded,
    tint: Color(0xFF8A5A22),
    title: 'Cafe Terra is nearby',
    body: 'Show this queue screen for 10% off coffee while you wait.',
  ),
  _DemoAd(
    icon: Icons.local_offer_rounded,
    tint: AppColors.warningOrange,
    title: 'Weekend dessert offer',
    body: 'Add a chef-special dessert to your table order today.',
  ),
  _DemoAd(
    icon: Icons.shopping_bag_rounded,
    tint: AppColors.accentPurple,
    title: 'Indiranagar boutique picks',
    body: 'Explore a curated local deal just 3 minutes away.',
  ),
];

class _HiddenObjectImageCard extends ConsumerWidget {
  const _HiddenObjectImageCard({required this.restaurantBranchId});

  final String restaurantBranchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = ref.watch(hiddenObjectImageProvider(restaurantBranchId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFFFF).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1AD8EAFE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D006687),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.image_search_rounded,
                  color: AppColors.deepTeal,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Find the differences',
                  style: TextStyle(
                    color: AppColors.navyText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          imageUrl.when(
            data: (url) => _HiddenObjectImageFrame(imageUrl: url),
            loading: () => const _HiddenObjectPlaceholder(loading: true),
            error: (_, _) => const _HiddenObjectPlaceholder(),
          ),
        ],
      ),
    );
  }
}

List<String> _meaningfulNoteLines(String? notes) =>
    notes
        ?.split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false) ??
    const [];

class _CustomerSpecialNotes extends StatelessWidget {
  const _CustomerSpecialNotes({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('customer-special-notes'),
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.accentPurple.withValues(alpha: 0.06),
        border: Border.all(
          color: AppColors.accentPurple.withValues(alpha: 0.18),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Special Notes',
            style: TextStyle(
              color: AppColors.navyText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•',
                    style: TextStyle(
                      color: AppColors.accentPurple,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: AppColors.navyText,
                        fontSize: 14,
                        height: 1.4,
                      ),
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

class _HiddenObjectImageFrame extends StatelessWidget {
  const _HiddenObjectImageFrame({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return const _HiddenObjectPlaceholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _HiddenObjectPlaceholder(),
        ),
      ),
    );
  }
}

class _HiddenObjectPlaceholder extends StatelessWidget {
  const _HiddenObjectPlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF3FAFE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1A006687)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                loading
                    ? Icons.hourglass_empty_rounded
                    : Icons.add_photo_alternate_rounded,
                color: AppColors.deepTeal,
                size: 27,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loading ? 'Loading puzzle image' : 'Puzzle image pending',
              style: const TextStyle(
                color: AppColors.navyText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Find-the-difference image will appear here.',
              style: TextStyle(
                color: Color(0xFF607D8B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final hiddenObjectImageProvider = StreamProvider.autoDispose
    .family<String?, String>((ref, restaurantBranchId) {
      const useFirebase = bool.fromEnvironment('USE_FIREBASE');
      if (!useFirebase && !kIsWeb) return Stream.value(null);

      return FirebaseFirestore.instance
          .doc(FirestorePaths.restaurantBranch(restaurantBranchId))
          .snapshots()
          .map((snapshot) {
            final data = snapshot.data() ?? <String, dynamic>{};
            final puzzleUrls =
                (data['hiddenObjectPuzzleImageUrls'] as List<dynamic>?)
                    ?.whereType<String>()
                    .map((url) => url.trim())
                    .where((url) => url.isNotEmpty)
                    .toList() ??
                const <String>[];
            if (puzzleUrls.isNotEmpty) {
              final index = math.Random(
                DateTime.now().microsecondsSinceEpoch ^ snapshot.id.hashCode,
              ).nextInt(puzzleUrls.length);
              return puzzleUrls[index];
            }
            return data['hiddenObjectPuzzleImageUrl'] as String? ??
                data['waitPuzzleImageUrl'] as String?;
          });
    });

// ignore: unused_element
class _HiddenItemsScenePainter extends CustomPainter {
  const _HiddenItemsScenePainter({
    required this.foundIds,
    required this.targetIds,
  });

  final Set<String> foundIds;
  final Set<String> targetIds;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEFFAFF), Color(0xFFFFFCF7), Color(0xFFF4F1FF)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final tableRect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.18,
      size.width * 0.84,
      size.height * 0.68,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, const Radius.circular(28)),
      Paint()..color = Colors.white.withValues(alpha: 0.86),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect.deflate(1), const Radius.circular(27)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x1A006687),
    );

    _drawPlate(canvas, size, const Offset(0.48, 0.54));
    _drawMenu(canvas, size, const Offset(0.25, 0.35));
    _drawCup(canvas, size, const Offset(0.73, 0.35));
    _drawBowl(canvas, size, const Offset(0.36, 0.72));
    _drawDessert(canvas, size, const Offset(0.67, 0.70));
    _drawPlant(canvas, size, const Offset(0.16, 0.72));
    _drawGift(canvas, size, const Offset(0.84, 0.70));

    for (final item in _sceneItems) {
      _drawHiddenItem(canvas, size, item);
    }
  }

  void _drawPlate(Canvas canvas, Size size, Offset p) {
    final center = Offset(size.width * p.dx, size.height * p.dy);
    final radius = size.shortestSide * 0.25;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFEAF6FF));
    canvas.drawCircle(center, radius * 0.72, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x22006687),
    );
  }

  void _drawMenu(Canvas canvas, Size size, Offset p) {
    final rect = Rect.fromCenter(
      center: Offset(size.width * p.dx, size.height * p.dy),
      width: size.width * 0.18,
      height: size.height * 0.34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = const Color(0xFFF8FBFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x22006687),
    );
    for (var i = 0; i < 3; i += 1) {
      canvas.drawLine(
        rect.topLeft + Offset(12, 18 + i * 15),
        rect.topRight + Offset(-12, 18 + i * 15),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x33006687),
      );
    }
  }

  void _drawCup(Canvas canvas, Size size, Offset p) {
    final center = Offset(size.width * p.dx, size.height * p.dy);
    canvas.drawCircle(
      center,
      size.shortestSide * 0.105,
      Paint()..color = const Color(0xFFFFF7E8),
    );
    canvas.drawCircle(
      center,
      size.shortestSide * 0.07,
      Paint()..color = const Color(0xFF8A5A22).withValues(alpha: 0.72),
    );
  }

  void _drawBowl(Canvas canvas, Size size, Offset p) {
    final rect = Rect.fromCenter(
      center: Offset(size.width * p.dx, size.height * p.dy),
      width: size.width * 0.17,
      height: size.height * 0.13,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accentPurple.withValues(alpha: 0.65),
    );
  }

  void _drawDessert(Canvas canvas, Size size, Offset p) {
    final center = Offset(size.width * p.dx, size.height * p.dy);
    canvas.drawCircle(
      center,
      size.shortestSide * 0.07,
      Paint()..color = const Color(0xFFFFE3EE),
    );
    canvas.drawCircle(
      center + Offset(size.width * 0.016, -size.height * 0.018),
      size.shortestSide * 0.024,
      Paint()..color = AppColors.warningOrange,
    );
  }

  void _drawPlant(Canvas canvas, Size size, Offset p) {
    final center = Offset(size.width * p.dx, size.height * p.dy);
    final paint = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawOval(
      Rect.fromCenter(center: center + Offset(-10, -8), width: 22, height: 12),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center + Offset(8, -10), width: 22, height: 12),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center + Offset(0, 14), width: 34, height: 28),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFFFF7E8),
    );
  }

  void _drawGift(Canvas canvas, Size size, Offset p) {
    final rect = Rect.fromCenter(
      center: Offset(size.width * p.dx, size.height * p.dy),
      width: size.width * 0.1,
      height: size.height * 0.15,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = const Color(0xFFEFE8FF),
    );
    canvas.drawLine(
      rect.centerLeft,
      rect.centerRight,
      Paint()
        ..strokeWidth = 2
        ..color = AppColors.accentPurple.withValues(alpha: 0.5),
    );
  }

  void _drawHiddenItem(Canvas canvas, Size size, _PuzzleItem item) {
    final found = foundIds.contains(item.id);
    final target = targetIds.contains(item.id);
    final center = Offset(
      size.width * item.position.dx,
      size.height * item.position.dy,
    );

    if (found) {
      canvas.drawCircle(
        center,
        18,
        Paint()..color = AppColors.secondaryCyan.withValues(alpha: 0.28),
      );
      canvas.drawCircle(
        center,
        18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.deepTeal.withValues(alpha: 0.58),
      );
    }

    final painter = TextPainter(
      text: TextSpan(
        text: item.code,
        style: TextStyle(
          color: item.color.withValues(
            alpha: found ? 0.95 : (target ? 0.56 : 0.36),
          ),
          fontSize: found ? 14 : 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _HiddenItemsScenePainter oldDelegate) {
    return oldDelegate.foundIds != foundIds ||
        oldDelegate.targetIds != targetIds;
  }
}

class _PuzzleItem {
  const _PuzzleItem({
    required this.id,
    required this.name,
    required this.code,
    required this.color,
    required this.position,
  });

  final String id;
  final String name;
  final String code;
  final Color color;
  final Offset position;
}

const _sceneItems = [
  _PuzzleItem(
    id: 'spoon',
    name: 'Spoon',
    code: 'SP',
    color: AppColors.deepTeal,
    position: Offset(0.48, 0.29),
  ),
  _PuzzleItem(
    id: 'coffee',
    name: 'Coffee',
    code: 'CF',
    color: Color(0xFF7C5A39),
    position: Offset(0.73, 0.35),
  ),
  _PuzzleItem(
    id: 'cake',
    name: 'Cake',
    code: 'CK',
    color: AppColors.warningOrange,
    position: Offset(0.69, 0.67),
  ),
  _PuzzleItem(
    id: 'rice',
    name: 'Bowl',
    code: 'BW',
    color: AppColors.accentPurple,
    position: Offset(0.36, 0.71),
  ),
  _PuzzleItem(
    id: 'tea',
    name: 'Tea',
    code: 'TE',
    color: Color(0xFF0F7B83),
    position: Offset(0.77, 0.46),
  ),
  _PuzzleItem(
    id: 'leaf',
    name: 'Leaf',
    code: 'LF',
    color: Color(0xFF2E7D32),
    position: Offset(0.16, 0.62),
  ),
  _PuzzleItem(
    id: 'pizza',
    name: 'Slice',
    code: 'SL',
    color: Color(0xFFD86A2A),
    position: Offset(0.56, 0.50),
  ),
  _PuzzleItem(
    id: 'icecream',
    name: 'Dessert',
    code: 'DS',
    color: Color(0xFFB45386),
    position: Offset(0.64, 0.73),
  ),
  _PuzzleItem(
    id: 'menu',
    name: 'Menu',
    code: 'MN',
    color: AppColors.inkBlue,
    position: Offset(0.25, 0.35),
  ),
  _PuzzleItem(
    id: 'table',
    name: 'Table',
    code: 'TB',
    color: AppColors.deepTeal,
    position: Offset(0.49, 0.83),
  ),
  _PuzzleItem(
    id: 'star',
    name: 'Star',
    code: 'ST',
    color: Color(0xFFE7A500),
    position: Offset(0.54, 0.24),
  ),
  _PuzzleItem(
    id: 'gift',
    name: 'Gift',
    code: 'GF',
    color: AppColors.accentPurple,
    position: Offset(0.84, 0.70),
  ),
];

class _QueueStatusCard extends StatelessWidget {
  const _QueueStatusCard({
    required this.entry,
    required this.branchLink,
    required this.aheadCount,
  });

  final QueueEntry entry;
  final CustomerBranchLink branchLink;
  final int aheadCount;

  @override
  Widget build(BuildContext context) {
    return _Card(
      key: const ValueKey('queue-status-waiting'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CustomerRestaurantIdentityView(
            identity: branchLink.identity,
            layout: CustomerRestaurantIdentityLayout.compact,
          ),
          const SizedBox(height: 8),
          Text(
            '${entry.customerName} · Party of ${entry.partySize}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF607D8B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          _TokenHero(tokenCode: entry.tokenCode),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1A006687)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MetricBlock(
                    label: 'Parties Ahead',
                    value: partiesAheadLabel(aheadCount),
                    suffix: '',
                  ),
                ),
                Container(width: 1, height: 46, color: const Color(0x1A006687)),
                Expanded(child: _RemainingWaitMetric(entry: entry)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _GradientProgressBar(value: _progressValue(aheadCount)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FF),
              border: Border.all(color: const Color(0x1A006687)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.deepTeal,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stay nearby. We will update this screen when your table is ready.',
                    style: TextStyle(
                      color: AppColors.inkBlue,
                      fontSize: 14,
                      height: 19 / 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_meaningfulNoteLines(entry.notes).isNotEmpty) ...[
            const SizedBox(height: 16),
            _CustomerSpecialNotes(lines: _meaningfulNoteLines(entry.notes)),
          ],
        ],
      ),
    );
  }

  double _progressValue(int aheadCount) {
    final position = aheadCount.clamp(0, 12);
    return (1 - (position / 12)).clamp(0.08, 0.92);
  }
}

class _RemainingWaitMetric extends StatefulWidget {
  const _RemainingWaitMetric({required this.entry});

  final QueueEntry entry;

  @override
  State<_RemainingWaitMetric> createState() => _RemainingWaitMetricState();
}

class _RemainingWaitMetricState extends State<_RemainingWaitMetric> {
  Timer? _timer;
  late int _remainingMinutes;

  @override
  void initState() {
    super.initState();
    _remainingMinutes = remainingQueueWaitMinutes(widget.entry);
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshFromWallClock(),
    );
  }

  @override
  void didUpdateWidget(covariant _RemainingWaitMetric oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id ||
        oldWidget.entry.estimatedWaitMinutes !=
            widget.entry.estimatedWaitMinutes ||
        oldWidget.entry.joinedAt != widget.entry.joinedAt) {
      _refreshFromWallClock();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshFromWallClock() {
    final nextValue = remainingQueueWaitMinutes(widget.entry);
    if (!mounted) {
      _remainingMinutes = nextValue;
      return;
    }
    if (nextValue != _remainingMinutes) {
      setState(() => _remainingMinutes = nextValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _MetricBlock(
      label: 'Estimated Wait',
      value: '$_remainingMinutes',
      suffix: _remainingMinutes == 1 ? 'min' : 'mins',
      alignEnd: true,
      showHourglass: true,
    );
  }
}

class _TokenHero extends StatelessWidget {
  const _TokenHero({required this.tokenCode});

  final String tokenCode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Token $tokenCode',
      child: Container(
        width: 124,
        height: 124,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF4FBFF),
          border: Border.all(
            color: AppColors.primaryTeal.withValues(alpha: 0.24),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryTeal.withValues(alpha: 0.24),
              blurRadius: 28,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: AppColors.accentPurple.withValues(alpha: 0.12),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Center(
          child: Text(
            tokenCode,
            style: const TextStyle(
              color: AppColors.deepTeal,
              fontFamily: 'JetBrains Mono',
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Semantics(
          label: 'Progress Bar',
          value: '${(clampedValue * 100).round()}%',
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F2F9),
              borderRadius: BorderRadius.circular(999),
            ),
            clipBehavior: Clip.antiAlias,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: constraints.maxWidth * clampedValue,
                decoration: const BoxDecoration(
                  gradient: AppColors.progressGradient,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.suffix,
    this.alignEnd = false,
    this.showHourglass = false,
  });

  final String label;
  final String value;
  final String suffix;
  final bool alignEnd;
  final bool showHourglass;

  @override
  Widget build(BuildContext context) {
    final alignment = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF607D8B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showHourglass) ...[
                const _HourglassPulse(size: 20),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.deepTeal,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (suffix.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  suffix,
                  style: const TextStyle(
                    color: AppColors.navyText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HourglassPulse extends StatefulWidget {
  const _HourglassPulse({this.size = 16});

  final double size;

  @override
  State<_HourglassPulse> createState() => _HourglassPulseState();
}

class _HourglassPulseState extends State<_HourglassPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final turn = progress < 0.56
              ? 0.0
              : progress < 0.84
              ? Curves.easeInOut.transform((progress - 0.56) / 0.28)
              : 1.0;
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _HourglassPainter(
                progress: progress,
                angle: math.pi * turn,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HourglassPainter extends CustomPainter {
  const _HourglassPainter({required this.progress, required this.angle});

  final double progress;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..translate(-center.dx, -center.dy);

    final pulse = 0.18 + 0.08 * math.sin(progress * math.pi * 2).abs();
    canvas.drawCircle(
      center,
      size.width * 0.48,
      Paint()..color = AppColors.warningOrange.withValues(alpha: pulse),
    );

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.deepTeal;

    final left = size.width * 0.28;
    final right = size.width * 0.72;
    final top = size.height * 0.18;
    final bottom = size.height * 0.82;
    final waist = Offset(size.width * 0.5, size.height * 0.5);

    canvas.drawLine(Offset(left, top), Offset(right, top), outline);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), outline);
    canvas.drawPath(
      Path()
        ..moveTo(left, top)
        ..lineTo(right, top)
        ..lineTo(waist.dx, waist.dy)
        ..close()
        ..moveTo(left, bottom)
        ..lineTo(right, bottom)
        ..lineTo(waist.dx, waist.dy)
        ..close(),
      outline,
    );

    final sandProgress = (progress / 0.56).clamp(0.0, 1.0);
    final sand = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.warningOrange;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * (0.38 + sandProgress * 0.04), top + 3)
        ..lineTo(size.width * (0.62 - sandProgress * 0.04), top + 3)
        ..lineTo(waist.dx, size.height * (0.43 + sandProgress * 0.04))
        ..close(),
      sand,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.36, bottom - 3)
        ..lineTo(size.width * 0.64, bottom - 3)
        ..lineTo(waist.dx, size.height * (0.66 - sandProgress * 0.08))
        ..close(),
      sand,
    );
    canvas.drawCircle(
      Offset(waist.dx, size.height * (0.48 + sandProgress * 0.08)),
      size.width * 0.035,
      sand,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HourglassPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.angle != angle;
  }
}

class _InlineReadyCard extends ConsumerWidget {
  const _InlineReadyCard({
    required this.restaurantBranchId,
    required this.branchLink,
    required this.entry,
    required this.onTheWay,
  });

  final String restaurantBranchId;
  final CustomerBranchLink branchLink;
  final QueueEntry entry;
  final bool onTheWay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      key: ValueKey(
        onTheWay ? 'queue-status-on_the_way' : 'queue-status-reserved',
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryTeal.withValues(alpha: 0.26),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.deepTeal,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            onTheWay ? "We'll see you soon!" : 'Your table is ready!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.deepTeal,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          CustomerRestaurantIdentityView(identity: branchLink.identity),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1A006687)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ReadyMetric(
                    label: 'Assigned Table',
                    value: entry.assignedTableNumber ?? 'Desk',
                  ),
                ),
                Container(width: 1, height: 48, color: const Color(0x1A006687)),
                Expanded(child: _HoldCountdownMetric(entry: entry)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!onTheWay) ...[
            EzqButton(
              label: "I'm on my way",
              onPressed: () async {
                await ref
                    .read(customerQueueRepositoryProvider)
                    .markOnTheWay(
                      restaurantBranchId: restaurantBranchId,
                      queueEntryId: entry.id,
                      phone: entry.phone,
                    );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Hostess notified you're on the way"),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryTeal.withValues(alpha: 0.24),
                ),
              ),
              child: const Text(
                "The host knows you're on the way.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: entry.extensionUsed
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(customerQueueRepositoryProvider)
                            .extendHold(
                              restaurantBranchId: restaurantBranchId,
                              queueEntryId: entry.id,
                              phone: entry.phone,
                            );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Your table hold was extended by 5 minutes.',
                            ),
                          ),
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not extend the table hold. Please ask the host.',
                            ),
                          ),
                        );
                      }
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepTeal,
                side: const BorderSide(color: AppColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: Text(
                entry.extensionUsed
                    ? '5 minute extension used'
                    : 'Need 5 more minutes',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x33E05C5C)),
            ),
            child: const Text(
              'Please arrive within 5 minutes. If you miss the hold window, your place may move back in queue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFBA1A1A),
                fontSize: 13,
                height: 18 / 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyMetric extends StatelessWidget {
  const _ReadyMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.deepTeal,
              fontFamily: 'JetBrains Mono',
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _HoldCountdownMetric extends StatefulWidget {
  const _HoldCountdownMetric({required this.entry});

  final QueueEntry entry;

  @override
  State<_HoldCountdownMetric> createState() => _HoldCountdownMetricState();
}

class _HoldCountdownMetricState extends State<_HoldCountdownMetric> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _remainingHold();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant _HoldCountdownMetric oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.reservedAt != widget.entry.reservedAt ||
        oldWidget.entry.extensionUsed != widget.entry.extensionUsed) {
      _refresh();
    }
  }

  Duration _remainingHold() {
    final reservedAt = widget.entry.reservedAt;
    if (reservedAt == null) return Duration.zero;
    final holdMinutes = widget.entry.extensionUsed ? 10 : 5;
    final remaining = reservedAt
        .add(Duration(minutes: holdMinutes))
        .difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _refresh() {
    final next = _remainingHold();
    if (mounted && next.inSeconds != _remaining.inSeconds) {
      setState(() => _remaining = next);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return _ReadyMetric(label: 'Holding For', value: '$minutes:$seconds');
  }
}

class _InlineSeatedCard extends StatelessWidget {
  const _InlineSeatedCard({required this.entry, required this.branchLink});

  final QueueEntry entry;
  final CustomerBranchLink branchLink;

  @override
  Widget build(BuildContext context) {
    return _Card(
      key: const ValueKey('queue-status-seated'),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.successGreen,
            size: 96,
          ),
          const SizedBox(height: 24),
          const Text(
            'Enjoy your meal!',
            style: TextStyle(
              color: AppColors.navyText,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          CustomerRestaurantIdentityView(identity: branchLink.identity),
          const SizedBox(height: 14),
          Text(
            'You have been seated at ${entry.assignedTableNumber ?? 'your table'}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF3E484F), fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1FBDC8D0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1712A9DC),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}
