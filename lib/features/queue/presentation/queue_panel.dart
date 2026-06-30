import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../recommendation/domain/recommendation_types.dart';
import '../../tables/domain/restaurant_table.dart';
import '../domain/queue_entry.dart';
import '../domain/queue_status.dart';

class QueuePanel extends StatefulWidget {
  const QueuePanel({
    super.key,
    required this.queue,
    this.tableRecommendations = const {},
    this.initialVisibleCount = 8,
    this.spotlightEntryId,
    this.spotlightLabel,
    this.secondarySpotlightEntryId,
    this.secondarySpotlightLabel,
    this.autoScrollSpotlight = false,
    required this.availableTables,
    required this.onReserve,
    required this.onSkip,
    this.onEntryTapped,
    this.onRecommendationSelected,
    this.onNoAvailableTables,
  });

  final List<QueueEntry> queue;
  final Map<String, List<QueueTableRecommendation>> tableRecommendations;
  final int initialVisibleCount;
  final String? spotlightEntryId;
  final String? spotlightLabel;
  final String? secondarySpotlightEntryId;
  final String? secondarySpotlightLabel;
  final bool autoScrollSpotlight;
  final List<RestaurantTable> availableTables;
  final void Function(QueueEntry entry) onReserve;
  final void Function(QueueEntry entry) onSkip;
  final void Function(QueueEntry entry)? onEntryTapped;
  final void Function(
    QueueEntry entry,
    QueueTableRecommendation recommendation,
  )?
  onRecommendationSelected;
  final VoidCallback? onNoAvailableTables;

  @override
  State<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends State<QueuePanel> {
  bool _showAll = false;
  String _queueSignature = '';

  @override
  void initState() {
    super.initState();
    _queueSignature = _currentQueueSignature();
  }

  @override
  void didUpdateWidget(covariant QueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _currentQueueSignature();
    if (nextSignature == _queueSignature) return;
    _queueSignature = nextSignature;
    _showAll = false;
  }

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final visibleCount = _showAll
        ? widget.queue.length
        : _boundedVisibleCount();
    final visibleQueue = widget.queue.take(visibleCount).toList();
    final hiddenCount = widget.queue.length - visibleQueue.length;
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
          for (final entry in visibleQueue) ...[
            Builder(
              builder: (context) {
                final spotlightTone = _spotlightToneFor(entry.id);
                return AnimatedSwitcher(
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
                    enabled:
                        widget.autoScrollSpotlight &&
                        spotlightTone == _QueueSpotlightTone.best,
                    child: _QueueEntryCard(
                      entry: entry,
                      recommendations:
                          widget.tableRecommendations[entry.id] ?? const [],
                      spotlightTone: spotlightTone,
                      spotlightLabel: _spotlightLabelFor(entry.id),
                      availableTables: widget.availableTables,
                      onReserve: () => widget.onReserve(entry),
                      onSkip: () => widget.onSkip(entry),
                      onNoAvailableTables: widget.onNoAvailableTables,
                      onTap: widget.onEntryTapped != null
                          ? () => widget.onEntryTapped!(entry)
                          : null,
                      onRecommendationSelected:
                          widget.onRecommendationSelected == null
                          ? null
                          : (recommendation) =>
                                widget.onRecommendationSelected!(
                                  entry,
                                  recommendation,
                                ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          if (hiddenCount > 0)
            _LoadMoreQueueButton(
              hiddenCount: hiddenCount,
              onPressed: () => setState(() => _showAll = true),
            )
          else if (_showAll && widget.queue.length > widget.initialVisibleCount)
            _ShowLessQueueButton(
              onPressed: () => setState(() => _showAll = false),
            ),
        ],
      ),
    );
  }

  _QueueSpotlightTone? _spotlightToneFor(String entryId) {
    if (entryId == widget.spotlightEntryId) return _QueueSpotlightTone.best;
    if (entryId == widget.secondarySpotlightEntryId) {
      return _QueueSpotlightTone.nextBest;
    }
    return null;
  }

  String? _spotlightLabelFor(String entryId) {
    if (entryId == widget.spotlightEntryId) return widget.spotlightLabel;
    if (entryId == widget.secondarySpotlightEntryId) {
      return widget.secondarySpotlightLabel;
    }
    return null;
  }

  int _boundedVisibleCount() {
    if (widget.queue.isEmpty) return 0;
    if (widget.initialVisibleCount <= 0) return 1;
    if (widget.initialVisibleCount > widget.queue.length) {
      return widget.queue.length;
    }
    return widget.initialVisibleCount;
  }

  String _currentQueueSignature() {
    return [
      for (final entry in widget.queue) entry.id,
      'count:${widget.initialVisibleCount}',
      'best:${widget.spotlightEntryId ?? ''}',
      'next:${widget.secondarySpotlightEntryId ?? ''}',
    ].join('|');
  }
}

class QueueTableRecommendation {
  const QueueTableRecommendation({
    required this.tableId,
    required this.tableNumber,
    required this.openSeats,
    required this.capacity,
    required this.isShared,
    required this.tone,
  });

  final String tableId;
  final String tableNumber;
  final int openSeats;
  final int capacity;
  final bool isShared;
  final QueueTableRecommendationTone tone;
}

enum QueueTableRecommendationTone { best, nextBest }

enum _QueueSpotlightTone { best, nextBest }

class _LoadMoreQueueButton extends StatelessWidget {
  const _LoadMoreQueueButton({
    required this.hiddenCount,
    required this.onPressed,
  });

  final int hiddenCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.expand_more_rounded),
        label: Text('Load more ($hiddenCount)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepTeal,
          side: BorderSide(color: AppColors.line.withValues(alpha: 0.82)),
          textStyle: TextStyle(
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _ShowLessQueueButton extends StatelessWidget {
  const _ShowLessQueueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.expand_less_rounded),
        label: const Text('Show less'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.deepTeal,
          textStyle: TextStyle(
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
    required this.recommendations,
    required this.spotlightTone,
    required this.spotlightLabel,
    required this.availableTables,
    required this.onReserve,
    required this.onSkip,
    this.onNoAvailableTables,
    this.onTap,
    this.onRecommendationSelected,
  });

  final QueueEntry entry;
  final List<QueueTableRecommendation> recommendations;
  final _QueueSpotlightTone? spotlightTone;
  final String? spotlightLabel;
  final List<RestaurantTable> availableTables;
  final VoidCallback onReserve;
  final VoidCallback onSkip;
  final VoidCallback? onNoAvailableTables;
  final VoidCallback? onTap;
  final void Function(QueueTableRecommendation recommendation)?
  onRecommendationSelected;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final canReserve = entry.status == QueueStatus.waiting;
    final spotlight = spotlightTone != null;
    final waitedMinutes = entry.waitingMinutesSince(DateTime.now());
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: spotlight
              ? Padding(
                  key: const ValueKey('spotlight-chip'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecommendationChip(
                    label: spotlightLabel ?? '${entry.tokenCode} is next',
                    tone: spotlightTone!,
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
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      entry.customerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
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
              label: '$waitedMinutes min',
            ),
            if (_prefersSharedSeating(entry)) const _SharedSeatingPill(),
          ],
        ),
        if (recommendations.isNotEmpty) ...[
          SizedBox(height: compact ? 8 : 10),
          for (final recommendation in recommendations) ...[
            _QueueTableRecommendationStrip(
              recommendation: recommendation,
              partySize: entry.partySize,
              onPressed: onRecommendationSelected == null
                  ? null
                  : () => onRecommendationSelected!(recommendation),
            ),
            if (recommendation != recommendations.last)
              SizedBox(height: compact ? 6 : 7),
          ],
        ],
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
                onNoAvailableTables: onNoAvailableTables,
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
                  onNoAvailableTables: onNoAvailableTables,
                ),
              ),
              const SizedBox(width: 8),
              _SkipAction(canSkip: canReserve, onSkip: onSkip),
            ],
          ),
      ],
    );
    final animatedCard = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: spotlight ? 1 : 0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, glow, child) {
        final toneColor = _spotlightColor(spotlightTone);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: spotlight
                ? Color.alphaBlend(
                    toneColor.withValues(alpha: 0.08),
                    const Color(0xFFF7F9FF),
                  )
                : const Color(0xFFF7F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: spotlight ? toneColor : const Color(0x1ABDC8D0),
              width: spotlight ? 2.5 : 1,
            ),
            boxShadow: spotlight
                ? [
                    BoxShadow(
                      color: toneColor.withValues(alpha: 0.34),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: toneColor.withValues(alpha: 0.18),
                      blurRadius: 44,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: content,
        );
      },
    );
    if (onTap == null) return animatedCard;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: animatedCard,
      ),
    );
  }

  Color _spotlightColor(_QueueSpotlightTone? tone) {
    return switch (tone) {
      _QueueSpotlightTone.best => AppColors.successGreen,
      _QueueSpotlightTone.nextBest => AppColors.recommendationYellow,
      null => AppColors.accentPurple,
    };
  }
}

bool _prefersSharedSeating(QueueEntry entry) {
  return entry.customerPreferences?.seatingPreference ==
      SeatingPreference.anyAvailable;
}

class _SharedSeatingPill extends StatelessWidget {
  const _SharedSeatingPill();

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33FC8019)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.group_add_rounded,
            size: compact ? 13 : 14,
            color: const Color(0xFFB75B00),
          ),
          const SizedBox(width: 4),
          Text(
            'Share',
            style: TextStyle(
              color: const Color(0xFF8A4B00),
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueTableRecommendationStrip extends StatelessWidget {
  const _QueueTableRecommendationStrip({
    required this.recommendation,
    required this.partySize,
    this.onPressed,
  });

  final QueueTableRecommendation recommendation;
  final int partySize;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final spareSeats = recommendation.openSeats - partySize;
    final color = recommendation.tone == QueueTableRecommendationTone.best
        ? AppColors.successGreen
        : AppColors.recommendationYellow;
    final rankLabel = recommendation.tone == QueueTableRecommendationTone.best
        ? 'Best'
        : 'Next';
    final pathLabel = recommendation.isShared ? 'Share' : 'Empty';
    final fitLabel = spareSeats == 0
        ? 'exact fit'
        : '$spareSeats spare ${spareSeats == 1 ? 'seat' : 'seats'}';

    final strip = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              recommendation.isShared
                  ? Icons.groups_2_rounded
                  : Icons.event_seat_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$rankLabel: $pathLabel ${recommendation.tableNumber} · $fitLabel',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.navyText,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Tooltip(
            message: 'Seat at ${recommendation.tableNumber}',
            child: Container(
              width: compact ? 28 : 30,
              height: compact ? 28 : 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                Icons.touch_app_rounded,
                color: color,
                size: compact ? 16 : 17,
              ),
            ),
          ),
        ],
      ),
    );
    if (onPressed == null) return strip;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onPressed, child: strip),
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

class _RecommendationChip extends StatelessWidget {
  const _RecommendationChip({required this.label, required this.tone});

  final String label;
  final _QueueSpotlightTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _QueueSpotlightTone.best => AppColors.successGreen,
      _QueueSpotlightTone.nextBest => AppColors.recommendationYellow,
    };
    final foreground = color.computeLuminance() > 0.56
        ? AppColors.navyText
        : Colors.white;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: foreground),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: foreground,
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
    this.onNoAvailableTables,
  });

  final bool canReserve;
  final List<RestaurantTable> availableTables;
  final String statusLabel;
  final VoidCallback onReserve;
  final VoidCallback? onNoAvailableTables;

  @override
  Widget build(BuildContext context) {
    if (!canReserve) {
      return OutlinedButton(onPressed: null, child: Text(statusLabel));
    }
    return EzqButton(
      label: 'Reserve',
      onPressed: availableTables.isEmpty ? onNoAvailableTables : onReserve,
    );
  }
}
