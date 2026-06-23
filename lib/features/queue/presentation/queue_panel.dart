import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../tables/domain/restaurant_table.dart';
import '../domain/queue_entry.dart';
import '../domain/queue_status.dart';

class QueuePanel extends StatelessWidget {
  const QueuePanel({
    super.key,
    required this.queue,
    this.spotlightEntryId,
    this.spotlightLabel,
    this.autoScrollSpotlight = false,
    required this.availableTables,
    required this.onReserve,
    required this.onSkip,
  });

  final List<QueueEntry> queue;
  final String? spotlightEntryId;
  final String? spotlightLabel;
  final bool autoScrollSpotlight;
  final List<RestaurantTable> availableTables;
  final void Function(QueueEntry entry) onReserve;
  final void Function(QueueEntry entry) onSkip;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1ABDC8D0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F006687),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Queue',
            style: TextStyle(
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search token or name',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          for (final entry in queue) ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                );
              },
              child: _SpotlightAutoScroller(
                key: ValueKey('${entry.id}-${entry.status.wireName}'),
                enabled: autoScrollSpotlight && entry.id == spotlightEntryId,
                child: _QueueEntryCard(
                  entry: entry,
                  spotlight: entry.id == spotlightEntryId,
                  spotlightLabel: entry.id == spotlightEntryId
                      ? spotlightLabel
                      : null,
                  availableTables: availableTables,
                  onReserve: () => onReserve(entry),
                  onSkip: () => onSkip(entry),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SpotlightAutoScroller extends StatefulWidget {
  const _SpotlightAutoScroller({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<_SpotlightAutoScroller> createState() => _SpotlightAutoScrollerState();
}

class _SpotlightAutoScrollerState extends State<_SpotlightAutoScroller> {
  @override
  void initState() {
    super.initState();
    _scheduleScrollIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _SpotlightAutoScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _scheduleScrollIfNeeded();
    }
  }

  void _scheduleScrollIfNeeded() {
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 560),
        curve: Curves.easeInOutCubic,
        alignment: 0.22,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _QueueEntryCard extends StatelessWidget {
  const _QueueEntryCard({
    required this.entry,
    required this.spotlight,
    required this.spotlightLabel,
    required this.availableTables,
    required this.onReserve,
    required this.onSkip,
  });

  final QueueEntry entry;
  final bool spotlight;
  final String? spotlightLabel;
  final List<RestaurantTable> availableTables;
  final VoidCallback onReserve;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final canReserve = entry.status == QueueStatus.waiting;
    final waitedMinutes = DateTime.now()
        .difference(entry.joinedAt)
        .inMinutes
        .clamp(0, 24 * 60);
    final joinedTime = DateTimeUtils.shortTime(entry.joinedAt);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: spotlight ? 1 : 0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, glow, child) {
        return AnimatedScale(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          scale: spotlight ? 1.025 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.all(compact ? 12 : 16),
            decoration: BoxDecoration(
              gradient: spotlight
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryTeal.withValues(alpha: 0.11),
                        AppColors.accentPurple.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.96),
                      ],
                    )
                  : null,
              color: spotlight ? null : const Color(0xFFF7F9FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: spotlight
                    ? AppColors.accentPurple.withValues(alpha: 0.36)
                    : const Color(0x1ABDC8D0),
                width: spotlight ? 1.4 : 1,
              ),
              boxShadow: [
                if (spotlight)
                  BoxShadow(
                    color: AppColors.accentPurple.withValues(
                      alpha: 0.16 + (glow * 0.08),
                    ),
                    blurRadius: 24 + (glow * 8),
                    offset: const Offset(0, 12),
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: spotlight
                ? Padding(
                    key: const ValueKey('spotlight-chip'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NextUpChip(
                      label: spotlightLabel ?? '${entry.tokenCode} is next',
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-spotlight-chip')),
          ),
          Row(
            children: [
              Text(
                entry.tokenCode,
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontFamily: 'JetBrains Mono',
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Text(
                  entry.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'Party ${entry.partySize}',
                style: TextStyle(fontSize: compact ? 12 : 14),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _QueueMetaPill(
                icon: Icons.timer_outlined,
                label: 'Waiting $waitedMinutes min',
              ),
              _QueueMetaPill(
                icon: Icons.login_rounded,
                label: 'Joined $joinedTime',
              ),
              Text(
                entry.status.wireName,
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReserveAction(
                  canReserve: canReserve,
                  availableTables: availableTables,
                  statusLabel: entry.status.wireName,
                  onReserve: onReserve,
                ),
                const SizedBox(height: 8),
                _SkipAction(canSkip: canReserve, onSkip: onSkip),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _ReserveAction(
                    canReserve: canReserve,
                    availableTables: availableTables,
                    statusLabel: entry.status.wireName,
                    onReserve: onReserve,
                  ),
                ),
                const SizedBox(width: 8),
                _SkipAction(canSkip: canReserve, onSkip: onSkip),
              ],
            ),
        ],
      ),
    );
  }
}

class _QueueMetaPill extends StatelessWidget {
  const _QueueMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 14, color: AppColors.deepTeal),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.navyText,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextUpChip extends StatelessWidget {
  const _NextUpChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x246A40D7),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkipAction extends StatelessWidget {
  const _SkipAction({required this.canSkip, required this.onSkip});

  final bool canSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    return SizedBox(
      height: 46,
      width: compact ? double.infinity : 92,
      child: OutlinedButton.icon(
        onPressed: canSkip ? onSkip : null,
        icon: const Icon(Icons.keyboard_double_arrow_right_rounded, size: 18),
        label: const Text('Skip'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPurple,
          side: BorderSide(
            color: canSkip
                ? AppColors.accentPurple.withValues(alpha: 0.34)
                : AppColors.line,
          ),
          backgroundColor: canSkip
              ? AppColors.accentPurple.withValues(alpha: 0.06)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ReserveAction extends StatelessWidget {
  const _ReserveAction({
    required this.canReserve,
    required this.availableTables,
    required this.statusLabel,
    required this.onReserve,
  });

  final bool canReserve;
  final List<RestaurantTable> availableTables;
  final String statusLabel;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    if (!canReserve) {
      return OutlinedButton(onPressed: null, child: Text(statusLabel));
    }
    return EzqButton(
      label: 'Reserve',
      onPressed: availableTables.isEmpty
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No available tables right now.')),
            )
          : onReserve,
    );
  }
}
