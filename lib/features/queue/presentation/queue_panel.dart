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
    required this.availableTables,
    required this.onReserve,
    required this.onSkip,
  });

  final List<QueueEntry> queue;
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
            _QueueEntryCard(
              entry: entry,
              availableTables: availableTables,
              onReserve: () => onReserve(entry),
              onSkip: () => onSkip(entry),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _QueueEntryCard extends StatelessWidget {
  const _QueueEntryCard({
    required this.entry,
    required this.availableTables,
    required this.onReserve,
    required this.onSkip,
  });

  final QueueEntry entry;
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
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1ABDC8D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                OutlinedButton(
                  onPressed: canReserve ? onSkip : null,
                  child: const Text('Skip'),
                ),
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
                OutlinedButton(
                  onPressed: canReserve ? onSkip : null,
                  child: const Text('Skip'),
                ),
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
